-- ============================================================================
-- Pasada 2 · "Observar" un gasto = HILO de comentarios (no un campo que se pisa)
-- ----------------------------------------------------------------------------
-- Contexto (handoff BD · 28-jun-2026):
--   En Finanzas, "Observar" marcaba un gasto con un único string (r.m.coment),
--   que se sobrescribía en cada observación: aprobador y rendidor se pisaban.
--   Debe ser un hilo tipo chat (autor + fecha, en secuencia), igual que el
--   módulo de Tareas ya resolvió con task_comments.
--
--   Esta migración clona ese patrón para gastos:
--     - tabla gasto_comments (espejo de task_comments, con project_id/gasto_id)
--     - RLS equivalente a project_operations (nivel operacion_creatividad + auth_ve_proyecto)
--     - GRANT a authenticated
--     - persistencia dentro de guardar_operaciones_4b (borro-y-reinserto),
--       igual que guardar_operaciones_4c hace con task_comments.
--   El flag estado='en_observacion' del gasto NO cambia; lo que cambia es que
--   el comentario deja de ser un string y pasa a ser esta tabla-hilo.
--
-- Contrato de payload (top-level, hermano de gastosOp):
--   p->'gastoComments' -> jsonb[] de { id, gastoId, autor, texto, ts }
--   (gasto_id = id del movimiento de gasto observado; posicion = orden en el array)
--   Si la clave 'gastoComments' NO viene en el payload, el hilo NO se toca
--   (protege contra clientes viejos que aún no cablean el campo).
-- ============================================================================

-- 1) Tabla del hilo ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.gasto_comments (
    id         text NOT NULL,
    project_id text NOT NULL,
    gasto_id   text NOT NULL,
    autor      text,
    texto      text,
    ts         text,
    posicion   integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.gasto_comments OWNER TO postgres;

ALTER TABLE ONLY public.gasto_comments
    ADD CONSTRAINT gasto_comments_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gasto_comments
    ADD CONSTRAINT gasto_comments_project_id_fkey
    FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_gasto_comments_proyecto_gasto
    ON public.gasto_comments USING btree (project_id, gasto_id);

-- 2) RLS (espejo de b_operations_* sobre project_operations) ------------------
ALTER TABLE public.gasto_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "b_gasto_comments_mod" ON public.gasto_comments TO authenticated
  USING (
    (public.auth_nivel('operacion_creatividad'::text, public.get_project_org(project_id)) = 'E'::text)
    AND public.auth_ve_proyecto(project_id, public.get_project_org(project_id))
  )
  WITH CHECK (
    public.auth_nivel('operacion_creatividad'::text, public.get_project_org(project_id)) = 'E'::text
  );

CREATE POLICY "b_gasto_comments_sel" ON public.gasto_comments FOR SELECT TO authenticated
  USING (
    (public.auth_nivel('operacion_creatividad'::text, public.get_project_org(project_id)) = ANY (ARRAY['E'::text, 'L'::text]))
    AND public.auth_ve_proyecto(project_id, public.get_project_org(project_id))
  );

-- 3) GRANT (espejo de task_comments) -----------------------------------------
GRANT ALL ON TABLE public.gasto_comments TO authenticated;
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE public.gasto_comments TO anon;
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE public.gasto_comments TO service_role;

-- 4) Ampliar guardar_operaciones_4b: persistir el hilo (borro-y-reinserto) ----
--    Esta versión incluye TAMBIÉN las columnas de caja de la Pasada 1
--    (caja_devuelto / caja_movimientos): es el cuerpo final del RPC.
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

  -- HILO DE "OBSERVAR" (gasto_comments): borro-y-reinserto, patrón de task_comments.
  -- Solo si el cliente envía la clave 'gastoComments' (clientes viejos no la pisan).
  if p ? 'gastoComments' then
    delete from gasto_comments where project_id = v_id;
    v_pos := 0;
    for elem in select * from jsonb_array_elements(coalesce(p->'gastoComments', '[]'::jsonb)) loop
      insert into gasto_comments (id, project_id, gasto_id, autor, texto, ts, posicion)
      values (coalesce(nullif(elem->>'id',''), 'gcm_' || replace(gen_random_uuid()::text, '-', '')),
              v_id, nullif(elem->>'gastoId',''), nullif(elem->>'autor',''),
              nullif(elem->>'texto',''), nullif(elem->>'ts',''), v_pos);
      v_pos := v_pos + 1;
    end loop;
  end if;

  return v_id;
end;
$$;

ALTER FUNCTION public.guardar_operaciones_4b(jsonb) OWNER TO postgres;
