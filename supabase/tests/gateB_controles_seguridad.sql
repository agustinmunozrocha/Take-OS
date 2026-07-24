-- ════════════════════════════════════════════════════════════════════════════
-- TEST · Controles de seguridad del Gate B
-- Autor: BD Expert · 24-jul-2026
--
-- Se pone ROJO (lanza excepción) si cualquiera de los controles se rompe.
-- Correr después de cada deploy, en staging y en producción. Solo lectura.
--
-- Existe porque un control de seguridad sin un test que lo vigile se degrada
-- solo. El caso 1 es el ejemplo: los DEFAULT PRIVILEGES de Supabase no se
-- pueden cambiar desde una migración, así que TODA tabla creada después del
-- revoke renace con TRUNCATE para anon/authenticated. La regla "acuérdate de
-- repetir el REVOKE" no basta; esto lo detecta.
-- ════════════════════════════════════════════════════════════════════════════

DO $test$
DECLARE
  v_grants      int;
  v_guard       int;
  v_policies    int;
  v_publicos    int;
  v_nivel_txt   text;
  v_detalle     text;
  v_fallos      text := '';
BEGIN

  -- ── 1. Ninguna tabla con privilegios no-DML para anon/authenticated ───────
  -- TRUNCATE no pasa por RLS: vaciaría una tabla ignorando las políticas.
  SELECT count(*), coalesce(string_agg(DISTINCT table_name, ', '), '')
    INTO v_grants, v_detalle
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public'
    AND grantee IN ('anon', 'authenticated')
    AND privilege_type IN ('TRUNCATE', 'TRIGGER', 'REFERENCES');

  IF v_grants > 0 THEN
    v_fallos := v_fallos || format(
      E'\n  [1] %s grants no-DML para anon/authenticated. Tablas: %s'
      E'\n      → Causa probable: una migración nueva con CREATE TABLE.'
      E'\n      → Fix: REVOKE TRUNCATE, TRIGGER, REFERENCES ON <tabla> FROM anon, authenticated;',
      v_grants, v_detalle);
  END IF;

  -- ── 2. El guard del soft-delete de proyectos sigue activo ─────────────────
  SELECT count(*) INTO v_guard
  FROM pg_trigger t
  JOIN pg_class c ON c.oid = t.tgrelid
  WHERE c.relname = 'projects'
    AND t.tgname = 'trg_guard_projects_soft_delete'
    AND NOT t.tgisinternal
    AND t.tgenabled <> 'D';

  IF v_guard <> 1 THEN
    v_fallos := v_fallos ||
      E'\n  [2] El trigger trg_guard_projects_soft_delete no existe o está deshabilitado.'
      E'\n      → Sin él, un perfil Ejecutivo puede borrar proyectos con un UPDATE directo.';
  END IF;

  -- ── 3. Las políticas de Storage siguen en pie ─────────────────────────────
  SELECT count(*) INTO v_policies
  FROM pg_policies
  WHERE schemaname = 'storage' AND tablename = 'objects'
    AND policyname IN ('takeos_storage_select','takeos_storage_insert',
                       'takeos_storage_update','takeos_storage_delete',
                       'hp_select','hp_insert','hp_update','hp_delete');

  IF v_policies <> 8 THEN
    v_fallos := v_fallos || format(
      E'\n  [3] Faltan políticas de Storage: hay %s de 8.', v_policies);
  END IF;

  -- ── 4. Ningún bucket público ──────────────────────────────────────────────
  SELECT count(*) INTO v_publicos FROM storage.buckets WHERE public;
  IF v_publicos > 0 THEN
    v_fallos := v_fallos || format(
      E'\n  [4] %s bucket(s) público(s). El modelo exige buckets privados + URL firmada.',
      v_publicos);
  END IF;

  -- ── 5. Las funciones de nivel nunca devuelven NULL ────────────────────────
  -- Contrato: sin membresía deben devolver 'none', NO NULL. Un NULL hace que
  -- una comparación por negación (nivel <> 'E') dé NULL en vez de TRUE, y el
  -- chequeo deja pasar en vez de bloquear: fail-open silencioso.
  SELECT auth_nivel_org_txt('eliminar_proyecto',
                            '00000000-0000-0000-0000-000000000000')
    INTO v_nivel_txt;

  IF v_nivel_txt IS NULL THEN
    v_fallos := v_fallos ||
      E'\n  [5] auth_nivel_org_txt devuelve NULL sin membresía (debe devolver ''none'').'
      E'\n      → Riesgo: usada con negación (<> ''E'') falla ABIERTA.'
      E'\n      → Fix: envolver el SELECT en COALESCE(..., ''none''), como auth_nivel.';
  END IF;

  -- ── Veredicto ─────────────────────────────────────────────────────────────
  IF v_fallos <> '' THEN
    RAISE EXCEPTION E'GATE B — CONTROLES ROTOS:%', v_fallos;
  END IF;

  RAISE NOTICE 'Gate B OK — los 5 controles en pie.';
END $test$;
