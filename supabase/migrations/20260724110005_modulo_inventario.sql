-- ════════════════════════════════════════════════════════════════════════════
-- Módulo de INVENTARIO de Rizora — 5 tablas + RLS multi-tenant
-- Autor: BD Expert · 10-jul-2026 · Validado en staging en transacción revertida.
--
-- NOTA DE TIMESTAMP (Code, 12-jul-2026): el handoff proponía 20260710130000, pero
-- ese slot ya estaba ocupado (renombrar_servicio_rpc en ~/Software) y quedaba FUERA
-- DE ORDEN respecto a migraciones ya aplicadas en staging (…165948/171621/231313).
-- Se renombró a 20260711000000 para que ordene después del último aplicado. El SQL
-- del módulo no cambió. Revisar con BD Expert antes del paso a producción.
--
-- QUÉ ES: inventario de equipos de rodaje, multi-productora (vendible a otras
-- productoras de Rizora). Cada organización maneja el suyo, aislado por RLS.
--
-- MODELO (aprobado por Agustín):
--   inv_categorias   — categorías por org (Cámara/Data, Lentes, Luces, …)
--   inv_bultos       — maletas/contenedores
--   inv_items        — el catálogo: el TIPO de cosa (no la unidad física)
--   inv_ubicaciones  — ítem ↔ bulto ↔ cantidad. SIN fila = suelto (Opción A).
--   inv_movimientos  — log append-only de cambios (mover/romper/perder/comprar…)
--
--   3 modos de rastreo por ítem: 'consumible' (no se cuenta), 'granel' (cantidad
--   total, p.ej. 5 C-Stands), 'activo' (caro; numero_serie opcional).
--   Ubicación OPCIONAL: un ítem puede estar suelto (C-Stands sin maleta) o ser
--   su propia maleta (Small Rig 220b) sin necesitar un contenedor aparte.
--
-- PERMISOS: cuelga del módulo 'bd' (mismo patrón que contacts/companies):
--   SELECT → nivel bd E o L · INSERT/UPDATE → bd E · DELETE → Administrador.
--   inv_movimientos es append-only (INSERT+SELECT; sin UPDATE/DELETE) para que
--   el historial sea confiable.
--
-- DESPLIEGUE: repo → staging → validar → producción. La siembra del inventario
-- de Primate va aparte, como dato, una vez arriba.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Tablas ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.inv_categorias (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  nombre          text NOT NULL,
  orden           int  NOT NULL DEFAULT 0,
  activo          boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, nombre)
);

CREATE TABLE IF NOT EXISTS public.inv_bultos (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  nombre          text NOT NULL,
  nota            text,
  activo          boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, nombre)
);

CREATE TABLE IF NOT EXISTS public.inv_items (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  categoria_id    bigint REFERENCES inv_categorias(id) ON DELETE SET NULL,
  nombre          text NOT NULL,
  modo            text NOT NULL DEFAULT 'granel'
                    CHECK (modo IN ('consumible','granel','activo')),
  cantidad_total  numeric NOT NULL DEFAULT 1,
  precio_arriendo numeric,                         -- CLP/día; NULL = sin precio
  arrendable      boolean NOT NULL DEFAULT true,   -- false = VB99, kit Zeiss
  numero_serie    text,                            -- solo activos de alto valor
  estado          text NOT NULL DEFAULT 'ok'
                    CHECK (estado IN ('ok','roto','perdido','en_reparacion')),
  nota            text,
  activo          boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.inv_ubicaciones (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  item_id         bigint NOT NULL REFERENCES inv_items(id)  ON DELETE CASCADE,
  bulto_id        bigint REFERENCES inv_bultos(id) ON DELETE SET NULL,  -- NULL = suelto
  cantidad        numeric NOT NULL DEFAULT 1,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.inv_movimientos (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  item_id         bigint REFERENCES inv_items(id) ON DELETE SET NULL,
  tipo            text NOT NULL
                    CHECK (tipo IN ('mover','romper','perder','comprar','reparar','ajustar')),
  bulto_origen    bigint REFERENCES inv_bultos(id) ON DELETE SET NULL,
  bulto_destino   bigint REFERENCES inv_bultos(id) ON DELETE SET NULL,
  cantidad        numeric,
  detalle         text,
  usuario         uuid DEFAULT auth.uid(),
  fecha           timestamptz NOT NULL DEFAULT now()
);

-- ── Índices ─────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS inv_categorias_org_idx   ON inv_categorias   (organization_id);
CREATE INDEX IF NOT EXISTS inv_bultos_org_idx        ON inv_bultos       (organization_id);
CREATE INDEX IF NOT EXISTS inv_items_org_idx         ON inv_items        (organization_id);
CREATE INDEX IF NOT EXISTS inv_items_categoria_idx   ON inv_items        (categoria_id);
CREATE INDEX IF NOT EXISTS inv_ubic_org_idx          ON inv_ubicaciones  (organization_id);
CREATE INDEX IF NOT EXISTS inv_ubic_item_idx         ON inv_ubicaciones  (item_id);
CREATE INDEX IF NOT EXISTS inv_ubic_bulto_idx        ON inv_ubicaciones  (bulto_id);
CREATE INDEX IF NOT EXISTS inv_mov_org_idx           ON inv_movimientos  (organization_id);
CREATE INDEX IF NOT EXISTS inv_mov_item_idx          ON inv_movimientos  (item_id);

-- ── RLS ─────────────────────────────────────────────────────────────────────
-- Patrón idéntico a contacts (módulo 'bd'): SELECT E/L · INSERT/UPDATE E ·
-- DELETE Administrador. Todo org-scoped. inv_movimientos: append-only.
ALTER TABLE inv_categorias  ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_bultos      ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_items       ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_ubicaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE inv_movimientos ENABLE ROW LEVEL SECURITY;

-- helper para no repetir: E/L lee, E escribe, admin borra
DO $rls$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['inv_categorias','inv_bultos','inv_items','inv_ubicaciones'] LOOP
    EXECUTE format($p$
      CREATE POLICY %1$s_sel ON public.%1$s FOR SELECT TO authenticated
        USING (auth_nivel('bd', organization_id) = ANY (ARRAY['E','L']));
      CREATE POLICY %1$s_ins ON public.%1$s FOR INSERT TO authenticated
        WITH CHECK (auth_nivel('bd', organization_id) = 'E');
      CREATE POLICY %1$s_upd ON public.%1$s FOR UPDATE TO authenticated
        USING (auth_nivel('bd', organization_id) = 'E')
        WITH CHECK (auth_nivel('bd', organization_id) = 'E');
      CREATE POLICY %1$s_del ON public.%1$s FOR DELETE TO authenticated
        USING (auth_codigo_perfil(organization_id) = 1);
    $p$, t);
  END LOOP;
END $rls$;

-- inv_movimientos: append-only (INSERT + SELECT; sin UPDATE ni DELETE)
CREATE POLICY inv_movimientos_sel ON public.inv_movimientos FOR SELECT TO authenticated
  USING (auth_nivel('bd', organization_id) = ANY (ARRAY['E','L']));
CREATE POLICY inv_movimientos_ins ON public.inv_movimientos FOR INSERT TO authenticated
  WITH CHECK (auth_nivel('bd', organization_id) = 'E');
