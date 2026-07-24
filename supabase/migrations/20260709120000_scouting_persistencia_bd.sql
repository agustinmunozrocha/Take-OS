-- Persistencia del Plan de Scouting (módulo Locaciones) en Supabase.
--
-- Hasta ahora el Plan de Scouting vivía SOLO en el respaldo local del navegador:
-- no sincronizaba a la base, no viajaba entre dispositivos ni entre usuarios, y
-- un refresco que recargara desde la base podía perderlo. Esta migración le da
-- una tabla propia (documento JSONB 1:1 por proyecto, mismo patrón que
-- project_shooting_plan / project_call_sheet) y la engancha a la RPC
-- guardar_operaciones_4a, que ya persiste los otros "planes" del proyecto
-- (rodajes, plan de rodaje, hoja de llamado) bajo el mismo permiso
-- (operacion_creatividad = 'E').
--
-- Cambio ADITIVO y reversible: tabla nueva + un bloque en una función existente.
-- No toca datos existentes, ni tenant isolation, ni auth. La función se
-- reemplaza con su cuerpo íntegro actual más el bloque de scouting.

-- ── Tabla: un documento de scouting por proyecto ──────────────────────────
create table if not exists "public"."project_scouting" (
    "project_id" "text" not null,
    "scouting"   "jsonb" default '{}'::"jsonb" not null,
    "updated_at" timestamp with time zone default "now"() not null
);

alter table "public"."project_scouting" owner to "postgres";

alter table only "public"."project_scouting"
    add constraint "project_scouting_pkey" primary key ("project_id");

alter table only "public"."project_scouting"
    add constraint "project_scouting_project_id_fkey"
    foreign key ("project_id") references "public"."projects"("id") on delete cascade;

-- ── RLS: mismo gate que el Plan de Rodaje / Hoja de Llamado ────────────────
alter table "public"."project_scouting" enable row level security;

create policy "b_scouting_mod" on "public"."project_scouting" to "authenticated"
    using ((("public"."auth_nivel"('operacion_creatividad'::"text", "public"."get_project_org"("project_id")) = 'E'::"text")
            and "public"."auth_ve_proyecto"("project_id", "public"."get_project_org"("project_id"))))
    with check (("public"."auth_nivel"('operacion_creatividad'::"text", "public"."get_project_org"("project_id")) = 'E'::"text"));

create policy "b_scouting_sel" on "public"."project_scouting" for select to "authenticated"
    using ((("public"."auth_nivel"('operacion_creatividad'::"text", "public"."get_project_org"("project_id")) = any (array['E'::"text", 'L'::"text"]))
            and "public"."auth_ve_proyecto"("project_id", "public"."get_project_org"("project_id"))));

-- ── GRANT (Supabase no expone la tabla sin esto). Postura endurecida: solo
--    authenticated; anon y service_role NO reciben acceso. ─────────────────
grant all on table "public"."project_scouting" to "authenticated";

-- ── Enganche a guardar_operaciones_4a: scouting como documento JSONB 1:1,
--    junto a plan de rodaje y hoja de llamado. Cuerpo íntegro actual + el
--    bloque de scouting (upsert si viene objeto; si no, se borra el documento
--    del proyecto). ─────────────────────────────────────────────────────────
create or replace function "public"."guardar_operaciones_4a"("p" "jsonb") returns "text"
    language "plpgsql" security definer
    set "search_path" to 'public'
    as $$
declare
  v_id text := p->>'id';
  v_org uuid;
  elem jsonb;
  v_pos int;
begin
  if v_id is null or v_id = '' then
    raise exception 'guardar_operaciones_4a: falta id';
  end if;

  -- Gate C: derivar organización y verificar permiso (fail-CLOSED)
  select organization_id into v_org from projects where id = v_id;
  if v_org is null then raise exception 'guardar_operaciones_4a: proyecto % sin organization_id', v_id; end if;
  perform rpc_assert_nivel('operacion_creatividad', 'E', v_org);

  delete from project_shoot_days where project_id = v_id;
  v_pos := 0;
  for elem in select * from jsonb_array_elements(coalesce(p->'rodajes', '[]'::jsonb)) loop
    insert into project_shoot_days (project_id, dia_id, fecha, activo, descripcion, posicion)
    values (v_id, elem->>'diaId', nullif(elem->>'fecha','')::date,
            coalesce((elem->>'activo')::boolean, false), nullif(elem->>'descripcion',''), v_pos);
    v_pos := v_pos + 1;
  end loop;

  if jsonb_typeof(p->'planRodaje') = 'object' then
    insert into project_shooting_plan (project_id, plan, updated_at)
    values (v_id, p->'planRodaje', now())
    on conflict (project_id) do update set plan = excluded.plan, updated_at = now();
  else
    delete from project_shooting_plan where project_id = v_id;
  end if;

  if jsonb_typeof(p->'hojaLlamado') = 'object' then
    insert into project_call_sheet (project_id, data, updated_at)
    values (v_id, p->'hojaLlamado', now())
    on conflict (project_id) do update set data = excluded.data, updated_at = now();
  else
    delete from project_call_sheet where project_id = v_id;
  end if;

  -- NUEVO · Plan de Scouting (documento JSONB 1:1, mismo patrón que arriba).
  if jsonb_typeof(p->'scouting') = 'object' then
    insert into project_scouting (project_id, scouting, updated_at)
    values (v_id, p->'scouting', now())
    on conflict (project_id) do update set scouting = excluded.scouting, updated_at = now();
  else
    delete from project_scouting where project_id = v_id;
  end if;

  return v_id;
end;
$$;

alter function "public"."guardar_operaciones_4a"("p" "jsonb") owner to "postgres";
