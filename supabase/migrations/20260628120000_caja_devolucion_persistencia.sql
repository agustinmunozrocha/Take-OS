-- ============================================================================
-- Pasada 1 · Persistir la DEVOLUCIÓN de caja de producción
-- ----------------------------------------------------------------------------
-- Contexto (handoff BD · 28-jun-2026):
--   La caja de producción tiene dos movimientos: INGRESO (lo que la productora
--   entrega) y DEVOLUCIÓN (lo que producción devuelve al cerrar). El ingreso ya
--   persiste en project_operations.caja_prod vía guardar_operaciones_4b, pero la
--   devolución (d.cajaDevuelto) y su libreta de movimientos (d.cajaMovs) vivían
--   solo en memoria y se perdían al recargar.
--
--   Modelo (A) elegido: espejar lo existente. Dos columnas en el mismo agregado
--   project_operations + ampliar el RPC que ya lo upsertea. Consistente con
--   caja_prod / op_movimientos / op_lineas_extra.
--
-- Forma de cada movimiento de caja (CLP enteros, sin decimales):
--   { id, tipo: 'ingreso' | 'devolucion', monto: <int>, fecha: 'YYYY-MM-DD', nota: <string> }
--
-- Contrato de payload (gastosOp / v_g):
--   v_g->>'cajaDevuelto'  -> numeric  (total devuelto)
--   v_g->'cajaMovs'       -> jsonb[]  (libreta de movimientos de caja)
-- ============================================================================

-- 1) Columnas nuevas en el agregado project_operations -----------------------
ALTER TABLE public.project_operations
  ADD COLUMN IF NOT EXISTS caja_devuelto    numeric DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS caja_movimientos jsonb   DEFAULT '[]'::jsonb NOT NULL;

-- (No hace falta GRANT: project_operations ya es tabla existente con sus
--  permisos/RLS; agregar columnas no cambia los GRANT de la tabla.)

-- 2) Ampliar guardar_operaciones_4b para upsertear las dos columnas nuevas ----
--    Se reescribe la función completa (CREATE OR REPLACE) preservando todo el
--    cuerpo actual; el único cambio respecto del esquema base es el bloque
--    de upsert de project_operations (columnas caja_devuelto / caja_movimientos).
CREATE OR REPLACE FUNCTION public.guardar_operaciones_4b(p jsonb) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_id  text := p->>'id';
  v_org uuid := (select organization_id from projects where id = p->>'id');
  v_g   jsonb := coalesce(p->'gastosOp', '{}'::jsonb);
  v_a   jsonb := coalesce(p->'asistentes', '{}'::jsonb);
  elem  jsonb;
  v_pos int;
begin
  if v_id is null or v_id = '' then raise exception 'guardar_operaciones_4b: falta id'; end if;
  if v_org is null then raise exception 'guardar_operaciones_4b: proyecto inexistente (%)', v_id; end if;
  perform rpc_assert_nivel('operacion_creatividad', 'E', v_org);  -- Gate C

  -- Responsables se maneja aparte (Punto 2): no va en este borrado masivo.
  delete from project_locations     where project_id = v_id;
  delete from project_crew_extra    where project_id = v_id;
  delete from project_external_crew where project_id = v_id;
  delete from project_op_budgets    where project_id = v_id;

  v_pos := 0;
  for elem in select * from jsonb_array_elements(coalesce(p->'locaciones', '[]'::jsonb)) loop
    insert into project_locations (project_id, loc_id, estado, costo, contratacion, notas_proy, posicion)
    values (v_id, elem->>'locId', nullif(elem->>'estado',''), nullif(elem->>'costo','')::numeric,
            nullif(elem->>'contratacion',''), nullif(elem->>'notasProy',''), v_pos);
    v_pos := v_pos + 1;
  end loop;

  for elem in select * from jsonb_array_elements(coalesce(p->'crewExtra', '[]'::jsonb)) loop
    insert into project_crew_extra (project_id, nombre, contact_id, medio_transporte)
    values (v_id, elem->>'nombre',
            (select id from contacts where organization_id = v_org and lower(nombre) = lower(elem->>'nombre') and deleted_at is null limit 1),
            nullif(elem->>'medioTransporte',''));
  end loop;

  v_pos := 0;
  for elem in select * from jsonb_array_elements(coalesce(p->'crewExternos', '[]'::jsonb)) loop
    insert into project_external_crew (project_id, tipo, nombre, rol, telefono, restriccion, direccion, comuna, posicion)
    values (v_id, nullif(elem->>'tipo',''), nullif(elem->>'nombre',''), nullif(elem->>'rol',''),
            nullif(elem->>'telefono',''), nullif(elem->>'restriccion',''), nullif(elem->>'direccion',''),
            nullif(elem->>'comuna',''), v_pos);
    v_pos := v_pos + 1;
  end loop;

  -- PUNTO 2: responsables de sección — solo Administrador(1)/Ejecutivo(2) reescriben;
  -- los demás perfiles PRESERVAN lo existente (no se toca).
  if auth_codigo_perfil(v_org) in (1,2) then
    delete from project_section_responsibles where project_id = v_id;
    for elem in select * from jsonb_array_elements(coalesce(p->'responsables', '[]'::jsonb)) loop
      insert into project_section_responsibles (project_id, seccion, nombre, contact_id)
      values (v_id, elem->>'seccion', nullif(elem->>'nombre',''),
              (select id from contacts where organization_id = v_org and lower(nombre) = lower(elem->>'nombre') and deleted_at is null limit 1));
    end loop;
  end if;

  insert into project_operations (project_id, asistentes_cliente, asistentes_agencia, asistentes_externo,
                                  caja_prod, caja_devuelto, caja_movimientos,
                                  op_movimientos, op_lineas_extra, updated_at)
  values (v_id,
          coalesce(nullif(v_a->>'cliente','')::int, 0),
          coalesce(nullif(v_a->>'agencia','')::int, 0),
          coalesce(nullif(v_a->>'externo','')::int, 0),
          coalesce(nullif(v_g->>'cajaProd','')::numeric, 0),
          coalesce(nullif(v_g->>'cajaDevuelto','')::numeric, 0),
          coalesce(v_g->'cajaMovs', '[]'::jsonb),
          coalesce(v_g->'movimientos', '[]'::jsonb),
          coalesce(v_g->'lineasExtra', '[]'::jsonb),
          now())
  on conflict (project_id) do update set
    asistentes_cliente = excluded.asistentes_cliente,
    asistentes_agencia = excluded.asistentes_agencia,
    asistentes_externo = excluded.asistentes_externo,
    caja_prod          = excluded.caja_prod,
    caja_devuelto      = excluded.caja_devuelto,
    caja_movimientos   = excluded.caja_movimientos,
    op_movimientos     = excluded.op_movimientos,
    op_lineas_extra    = excluded.op_lineas_extra,
    updated_at         = now();

  v_pos := 0;
  for elem in select * from jsonb_array_elements(coalesce(v_g->'presupuestos', '[]'::jsonb)) loop
    insert into project_op_budgets (id, project_id, nombre, linea, resp, asignado, posicion)
    values (coalesce(nullif(elem->>'id',''), 'opb_' || replace(gen_random_uuid()::text, '-', '')),
            v_id, nullif(elem->>'nombre',''), nullif(elem->>'linea',''), nullif(elem->>'resp',''),
            nullif(elem->>'asignado','')::numeric, v_pos);
    v_pos := v_pos + 1;
  end loop;

  return v_id;
end;
$$;

ALTER FUNCTION public.guardar_operaciones_4b(jsonb) OWNER TO postgres;
