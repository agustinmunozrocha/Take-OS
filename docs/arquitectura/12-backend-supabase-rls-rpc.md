# Backend Supabase de Rizora: esquema, RLS y contratos RPC

**Corpus**: `/home/juandlc/Trabajo/Take-OS/supabase/migrations/` — 14 archivos `.sql`, 9.157 líneas (`wc -l supabase/migrations/*.sql`). Volcado base: `20260616150834_remote_schema.sql` (7.354 líneas). Cifras de este informe: 78 tablas (`grep -c "CREATE TABLE"` sumado: 72 en el dump + 5 `default_*` en `20260616170000` + 1 `gasto_comments` en `20260628130000`), 157 `CREATE POLICY` (`grep -rhoi "CREATE POLICY" ... | wc -l`; 149 sobre `public`, 8 sobre `storage.objects`), 76 ocurrencias textuales de `SECURITY DEFINER` (`grep -rho "SECURITY DEFINER" ... | wc -l`; corresponden a 62 funciones distintas cuya definición vigente es DEFINER, de 77 funciones totales en `public` — las 15 restantes son INVOKER: `fn_norm_*`, `fn_jsarr`, `fn_title`, `set_updated_at`, `trg_norm_user_*`, `trg_touch/`, `trg_user_tool_documents_meta`; conteo por script Python sobre los `CREATE FUNCTION`), 104 `FOREIGN KEY` en el dump (`grep -c "FOREIGN KEY" 20260616150834_remote_schema.sql`).

---

## 1. Inventario de tablas y relaciones

### 1.1 `projects` y sus hijas

`projects` (`20260616150834_remote_schema.sql:3747`): PK `id text`, `organization_id uuid NOT NULL` → `organizations(id)`, `deleted_at`/`cerrado_at`/`aprobado_at` (soft-delete y ciclo de vida), y `version int NOT NULL DEFAULT 1` agregada en `20260621170000:32-33`. **29 tablas** tienen FK a `projects(id)` en el dump (`grep -o 'REFERENCES "public"."projects"' | wc -l` → 29) + `gasto_comments` (`20260628130000:43-45`) = **30 hijas**:

- **1:1 (PK = project_id)**: `project_commercial` (:3333), `project_financials` (:3461), `project_operations` (:3601), `project_quotation` (:3616), `project_shooting_plan` (:3705), `project_call_sheet` (:3238).
- **1:N con `ON DELETE CASCADE`**: `budget_line_items` (:2501, con `client_uuid uuid UNIQUE` + `version int` desde `20260621170000:39-49`), `project_assignments`, `project_cargos`, `project_client_payments`, `project_commissions`, `project_crew_extra`, `project_documents`, `project_external_crew`, `project_income_extras`, `project_locations`, `project_op_budgets`, `project_risks`, `project_section_responsibles`, `project_shoot_days`, `project_signals`, `project_tasks` (→ hijas `task_comments`, `task_attachments`), `quotation_offers`, `quotation_versions`, `project_cancellations`, `gasto_comments`.
- **Referencias laterales**: `legal_documents`, `notification_sends`, `user_notifications`, `project_members`.

### 1.2 BD de terceros: `contacts` / `companies` / `locations`

- `contacts` (:2764): `organization_id` → `organizations` `ON DELETE RESTRICT` (:5086), `deleted_at` (soft-delete). Hijas CASCADE: `contact_roles` (:5071), `contact_bank_accounts` (:5056, FK `bank_codigo_sbif` → `bank_institutions`), `contact_companies` (:5061-5066), `contact_talent_profiles` (:5076, 1:1).
- `companies` (:2579): `organization_id` → `organizations` RESTRICT (:5036); hija `company_relationships` CASCADE (:5046).
- `locations` (:2949): PK `loc_id text`, `organization_id` → `organizations` (:5161); `deleted_at` agregada en `20260629120000:23-24`.

### 1.3 Identidad y permisos

- `memberships` (:2971): `organization_id uuid`, `user_id uuid` → `auth.users` (:5181), `profile_id bigint` → `permission_profiles` (:5176), `contact_id` → `contacts` (:5166); CHECKs `tipo IN ('interno','externo')` y `estado IN ('activo','inactivo','pendiente')` (:2981-2982). Trigger `trg_proteger_ultimo_admin` (`20260616150835_triggers.sql:15`).
- `permission_profiles` (:3137): `(organization_id, codigo int, nombre)`; `profile_permissions` (:3188): `profile_id` → `permission_profiles` (:5246), `modulo text`, `nivel` CHECK `IN ('E','L','none')` (:3193). La matriz canónica se siembra desde `default_permission_profiles`/`default_profile_permissions` (`20260616170000:62-84`): **8 perfiles × 13 módulos = 104 filas** (perfil 1 Administrador todo 'E'; 2 Ejecutivo sin `datos_empresa/eliminar_proyecto/finanzas_consolidada/gestion_permisos`; 7 Invitado solo `operacion_creatividad` y `tareas` en 'L'; 8 Finanzas solo `finanzas_consolidada` y `tareas` en 'E').
- `organizations` (:3117): `plan text DEFAULT 'free'` con FK `organizations_plan_fk` → `plan_catalog(codigo)` `ON UPDATE CASCADE` (:5231). `plan_catalog` (:3162): `max_proyectos_activos int`, `max_colaboradores int`. `plan_features` (:3179): `(plan_codigo, feature)` → `plan_catalog` CASCADE (:5241).
- Onboarding: `org_invitations` (:3064), `invitation_rebind_requests` (:2878), `consent_terms`/`data_consents`/`cookie_consents`, `scheduled_account_deletions` (:3838, procesada por cron `20260616150836`: `cron.schedule('takeos-eliminaciones-diarias','0 4 * * *', procesar_eliminaciones_vencidas())`).

**RLS habilitado en 78/78 tablas** (`grep -rhoi "ENABLE ROW LEVEL SECURITY" | wc -l` → 78). Única tabla con RLS y **cero policies**: `app_config` (deny-all deliberado, documentado en `20260617144834:96-97`).

---

## 2. Contrato real de las 8 RPC `guardar_*`

Nombres distintos (grep sobre `CREATE ... FUNCTION public.guardar_`): `guardar_proyecto`, `guardar_cargos`, `guardar_pagos_cliente`, `guardar_operaciones_4a/4b/4c/4e`, `guardar_consentimiento_cookies`. Todas `SECURITY DEFINER SET search_path TO 'public'`.

### 2.1 `guardar_proyecto` — versionado optimista por fila

Definición vigente (tercera): `20260621180000_guardar_proyecto_persistir_he_config.sql:21` —

```sql
CREATE OR REPLACE FUNCTION public.guardar_proyecto(p jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
```

(La versión de `20260621170000:53-55` hizo `DROP FUNCTION IF EXISTS public.guardar_proyecto(jsonb)` porque cambió el retorno `text→jsonb` — breaking change documentado en :20-22; la de 180000 solo añade `he_config` con `CREATE OR REPLACE`, preservando grants.)

**Gates** (`20260621180000:56-70`): si el proyecto no existe → `rpc_assert_nivel('crear_proyecto','E',v_org)` + `rpc_assert_cupo_proyecto(v_org)` + exige `p.header`; si existe → `auth_codigo_perfil(v_org) is null` ⇒ `raise 'takeos_auth: sin membresía activa...'`. Luego cachea `v_n_info/v_n_pres/v_n_cot := coalesce(auth_nivel('info_proyecto'|'presupuesto'|'cotizacion', v_org),'none')`.

**Cabecera versionada** (projects + project_commercial como unidad, `:78-139`): UPDATE atómico con chequeo de versión:

```sql
where id = v_id and version = coalesce(nullif(v_header->>'version','')::int, -1);
if not found then
  raise exception 'TAKEOS_CONFLICT:%', jsonb_build_object('seccion','cabecera','ids', jsonb_build_array(v_id))::text;
end if;
```

El UPDATE hace `version = version + 1` (:90); el retorno incluye `headerVersion` nueva (:137-138). `project_commercial` se upsertea `on conflict (project_id) do update` bajo el mismo gate.

**Presupuesto por fila** (`:200-287`): contrato documentado en el propio SQL (:202-205): `p.presupuestoDiff = { upserts:[{clientUuid,version,...}], deletes:[{clientUuid,version}] }`; `version null` → fila nueva (`insert ... version 1 ... on conflict (client_uuid) do nothing`, idempotente ante doble-envío del autosave, :233-252); `version int` → `update ... where project_id=v_id and client_uuid=v_cu and version=v_row_ver` con `version = version + 1` (:257-272). DELETE con versión: si `not found` y la fila aún existe con otra versión → conflicto; si no existe → ya borrada, idempotente (:215-220). Los conflictos se **acumulan** en `v_conflicts` y se lanza UN solo raise al final (todo-o-nada, la transacción revierte):

```sql
raise exception 'TAKEOS_CONFLICT:%', jsonb_build_object('seccion','presupuesto','ids', v_conflicts)::text;   -- :283
```

Retorno: `{id, headerVersion?, budget:{versions:{<clientUuid>:<version>}}}` (:72,138,286).

**"Por presencia de clave"** (contrato de transición, `20260621170000:13-18`): las secciones no migradas se procesan **solo si la clave viene en `p`**: asignaciones `if (p ? 'asignaciones')` (:145), finanzas `if (p ? 'finanzas')` (:165), cotización `if ((p ? 'cotizacion') or (p ? 'versiones'))` (:292). Si la clave falta, la sección no se toca — un guardado parcial ya no borra lo no enviado. Dentro de cada sección el modelo sigue siendo el viejo: `delete from project_assignments/project_commissions/project_risks/project_income_extras/quotation_* where project_id = v_id` + reinsert, **sin versión** (:146, :173, :182, :191, :294-295, :315).

**Lado cliente**: `frontend/src/modules/dal.js:1458` (`_dalProyectoPayload`) manda `header` solo si `project._headerDirty || esNuevo` con `version: project._headerVersion ?? null`; el diff de presupuesto solo con filas `_dirty` o nuevas; las secciones viejas solo si su snapshot JSON cambió (dal.js:1526-1535). El conflicto lo parsea `manejarConflicto` (dal.js:1611-1624): `raw.match(/TAKEOS_CONFLICT:\s*(\{[\s\S]*\})/)` + `JSON.parse`, suspende autosave (`_autosaveSuspendedByConflict`) y muestra modal/banner una sola vez.

### 2.2 `guardar_operaciones_4a/4b/4c/4e` — ¿estado completo sin versionado?

**Confirmado con matices.** Ninguna de las cuatro tiene columna de versión ni chequeo optimista; devuelven `text` (el id). El comentario del cliente (dal.js:1714-1717: "CONTRATO: se manda el estado COMPLETO ... la RPC reemplaza todo; lo que no se manda, se borra") es exacto para 4a y 4e, y exacto-con-dos-excepciones para 4b; 4c reemplaza por sección gateada:

- **4a** (`20260616150834:1047`, firma `"guardar_operaciones_4a"("p" "jsonb") RETURNS "text"`): gate `rpc_assert_nivel('operacion_creatividad','E',v_org)` (:1064). `delete from project_shoot_days` + reinsert siempre (:1066-1073); `project_shooting_plan` y `project_call_sheet` se upsertean si `jsonb_typeof(p->'planRodaje'|'hojaLlamado')='object'`, **y se borran si no** (:1075-1089) — no hay key-guard; el cliente siempre manda ambos (null si vacíos, dal.js:1691-1699).
- **4b** (versión vigente `20260628130000:76`, firma `public.guardar_operaciones_4b(p jsonb) RETURNS text`; supersede a `20260628120000:35` que agregó `caja_devuelto/caja_movimientos`, y al dump :1099): gate `rpc_assert_nivel('operacion_creatividad','E',v_org)` (:90). Borrado masivo + reinsert de `project_locations/project_crew_extra/project_external_crew/project_op_budgets` (:93-96); upsert 1:1 de `project_operations` (:133-155). **Excepción 1**: `project_section_responsibles` solo se reescribe `if auth_codigo_perfil(v_org) in (1,2)` — otros perfiles PRESERVAN lo existente sin error (:122-131). **Excepción 2**: `gasto_comments` es key-guarded: `if p ? 'gastoComments' then delete ... reinsert` (:166-178) para no ser pisado por clientes viejos.
- **4c** (dump :1192): sin `rpc_assert_nivel` duro; exige membresía (`auth_codigo_perfil(v_org) is null` → raise :1211-1213) y luego reescribe **por sección según nivel**: tareas+comentarios+adjuntos solo `if auth_nivel('tareas', v_org)='E'` (:1216-1242), señales solo `if auth_nivel('operacion_creatividad', v_org)='E'` (:1245-1258). Sección sin nivel = se salta en silencio y retorna éxito.
- **4e** (dump :1268): gate `rpc_assert_nivel('operacion_creatividad','E',v_org)` (:1282); `delete from project_documents` + reinsert completo (:1284-1298).

### 2.3 Las otras dos `guardar_*`

- `guardar_cargos` (vigente `20260617160000:43`, firma `public.guardar_cargos(p_project_id text, p_cargos jsonb) RETURNS integer`): gates `rpc_assert_nivel('info_proyecto','E',v_org)` + `auth_ve_proyecto` (:68-71); **límite de plan POR PROYECTO**: `jsonb_array_length(p_cargos) > pc.max_colaboradores` ⇒ `RAISE 'TAKEOS_PLAN_LIMITE:colaboradores:%'` (:75-81); regla server-side "un externo no puede recibir Administrador ni Finanzas" (:91-93); estado-completo (`DELETE FROM project_cargos` :84).
- `guardar_pagos_cliente` (dump :1308, `("p_project_id" "text", "p_pagos" "jsonb") RETURNS integer`): `rpc_assert_nivel('finanzas_consolidada','E',v_org)` + `rpc_assert_plan('finanzas',v_org)` + `auth_ve_proyecto` (:1327-1331); estado-completo (:1334).

---

## 3. Modelo RLS

### 3.1 Clasificación de las 157 policies

Script Python sobre los `create policy` (152 capturadas por regex + 5 con nombre sin comillas en `20260616170000:47-51` = 157):

| Patrón | Tablas | Ejemplo |
|---|---|---|
| **4 policies SEL/INS/UPD/DEL por operación** | `contacts`, `companies`, `locations`, `projects`, `legal_documents`, `legal_templates`, `company_relationships`, `contact_bank_accounts`, `contact_companies`, `contact_roles`, `contact_talent_profiles` (11 tablas × 4 = 44) | `b_contacts_sel` (:5697) |
| **Par `_mod` (ALL) + `_sel`** | 37 tablas (casi todas las hijas de proyecto, `memberships`, `organizations`, `permission_profiles`, `profile_permissions`, `departments`, `notification_*`, `gasto_comments`…) = 74 | `b_operations_mod`/`b_operations_sel` (:5837/:5841) |
| **Solo SELECT (escritura solo vía RPC DEFINER)** | 17 tablas: `project_cargos`, `project_client_payments`, `project_commercial`, `org_invitations`, `user_notifications`, `audit_log`, `cookie_consents`, `data_consents`, `consent_terms`, `scheduled_account_deletions`, `invitation_rebind_requests`, `bank_institutions`, `dte_types`, `tax_rates`, `plan_catalog`, `plan_features`, `organization_branding`, `user_tool_versions` + las 5 `default_*` (=23 policies aprox.) | `default_pp_sel` (`20260616170000:47`) |
| **Solo INSERT** | `analytics_events` (1) | |
| **ALL propio-usuario** | `user_profiles`, `user_bank_accounts`, `user_tool_documents` (3) ; `user_tool_archive` SELECT+DELETE (2) | |
| **storage.objects** | 8: 4 `hp_*` (bucket `herramientas-personales`, carpeta = `auth.uid()`, dump :7281-7315) + 4 `takeos_storage_*` (8 buckets de org gateados por `auth_es_miembro_org_txt((storage.foldername(name))[1])`, y `documentos-legales` por `auth_nivel_org_txt('gastos_legal_notificaciones',…)`, :7318-7353) | |

Los predicados se apoyan en 6 helpers `SECURITY DEFINER STABLE` (dump): `auth_codigo_perfil(p_org uuid)` (:381), `auth_es_miembro_org_txt(text)` (:396), `auth_nivel(p_modulo text, p_org_id uuid)` (:412 — `COALESCE((SELECT pp.nivel FROM memberships m JOIN profile_permissions pp ...),'none')`), `auth_nivel_org_txt` (:432), `auth_plan_permite` (:450), `auth_ve_proyecto(p_project_id text, p_org_id uuid)` (:461 — `m.tipo='interno' OR EXISTS(project_cargos pc WHERE pc.invited_user_id=m.user_id AND pc.estado='activo')`), más los resolvers `get_project_org/get_contact_org/get_company_org/get_send_org/get_task_project` (:906-959). Patrón hija-de-proyecto: `auth_nivel('<modulo>', get_project_org(project_id)) = 'E'` (mod) o `= ANY(ARRAY['E','L'])` (sel), **AND `auth_ve_proyecto(...)`** — ej. `b_budget_mod`/`b_budget_sel` (:5565/:5569).

### 3.2 Verificación de las afirmaciones del cliente

**"Un externo NO puede leer contacts" (dal.js:248)** — *verificado solo como convención, no como invariante de policy*. `b_contacts_sel` (:5697):

```sql
CREATE POLICY "b_contacts_sel" ON "public"."contacts" FOR SELECT TO "authenticated" USING (("public"."auth_nivel"('bd'::"text", "organization_id") = ANY (ARRAY['E'::"text", 'L'::"text"])));
```

No consulta `memberships.tipo`. Un externo no lee `contacts` **si y solo si** su perfil tiene `bd='none'` (solo el perfil 7 Invitado en el seed, `20260616170000:82`). Pero `invitar_a_organizacion` (`20260617160000:164-166`) solo prohíbe perfiles 1 y 8 para externos; los perfiles 3-6 tienen `bd` en 'E' o 'L' (:78-81). El mitigante que hace verdadera la frase hoy es el flujo de invitación de externos por cargo (perfil Invitado). Ver Hallazgo H2.

**"La seguridad real de escritura la cierra el RPC SECURITY DEFINER (Gate C)" (dal.js:526-533)** — *verificado para las rutas RPC*: las 8 `guardar_*` + `eliminar/restaurar_proyecto` + `archivar_*` validan permiso adentro (`rpc_assert_nivel` en 4a:1064, 4b:`20260628130000:90`, 4e:1282, cargos:`20260617160000:68`, pagos:1327, proyecto:`20260621180000:57`; `auth_codigo_perfil(v_org) <> 1` en archivar `20260629120000:36`). `rpc_assert_nivel` (dump :2108-2135) niega con `takeos_auth: ...` si no hay membresía activa o el nivel no alcanza. Complemento: las tablas que solo se escriben por RPC no tienen policy de escritura (solo `_sel`): `project_cargos`, `project_client_payments`, `project_commercial`, `user_notifications` (COMMENT :3951: "escritura solo via RPC SECURITY DEFINER"). Las escrituras directas del cliente (contacts/companies/locations y sus hijas, legal_*, user_profiles, memberships, permission_profiles…) las cierra RLS `WITH CHECK`, no un RPC. **Excepción real detectada**: el soft-delete de proyectos (H1).

---

## 4. Protocolos de error y REVOKEs

### 4.1 Errores tipados (grep `TAKEOS_` en migrations)

| Marcador | Emisores SQL | Parser cliente |
|---|---|---|
| `TAKEOS_PLAN_LIMITE:proyectos:%` | `rpc_assert_cupo_proyecto` (dump :2101) — cuenta `projects WHERE deleted_at IS NULL AND cerrado_at IS NULL` vs `plan_catalog.max_proyectos_activos`; NULL = ilimitado (:2098) | `plan-limites.js:79-88` `raw.match(/TAKEOS_PLAN_LIMITE:\s*([a-z_]+)\s*:\s*(\d+)/i)` → modal de venta con el tope |
| `TAKEOS_PLAN_LIMITE:colaboradores:%` | `guardar_cargos` (`20260617160000:80`, por-proyecto) y el deprecado `rpc_assert_cupo_colaborador` (dump :2085, org-wide; COMMENT de deprecación en `20260617160000:218-219`) | ídem |
| `TAKEOS_PLAN:%` (feature) | `rpc_assert_plan` (dump :2147) sobre `auth_plan_permite`/`plan_features` | `plan-limites.js:89-95` `/TAKEOS_PLAN:\s*([a-z_]+)/i` → pantalla bloqueada o modal |
| `TAKEOS_CONFLICT:{seccion,ids}` | `guardar_proyecto` (`20260621180000:94` cabecera, `:283` presupuesto) | `dal.js:1614` |
| `takeos_auth: ...` (minúsculas, no tipado) | `rpc_assert_nivel` (:2125,2129,2133), `guardar_cargos` (:70), `guardar_pagos_cliente` (:1330), `guardar_proyecto` (:64), 4c (:1212), `asignar_cargo_a_miembro` (:294) | sin parser dedicado (cae al manejo genérico) |

### 4.2 Los REVOKE (defensa por capas + fidelidad de rebuild)

1. `20260616160154_revoke_funciones_internas.sql:6-18`: bucle `DO` que revoca `EXECUTE FROM PUBLIC, anon, authenticated` a toda función trigger y a las de prefijo `_` (auxiliares internas de la cadena DEFINER).
2. `20260617144834:53-72`: `REVOKE ... FROM PUBLIC, anon` + `GRANT ... TO authenticated` a las 7 RPC de escritura (`guardar_proyecto`, 4a/4b/4c/4e, `eliminar_proyecto`, `restaurar_proyecto`); :81-91 fija `search_path` a 11 utilitarias INVOKER; :96-97 documenta el deny-all de `app_config`.
3. `20260621120000:24-42`: `REVOKE ... FROM PUBLIC, anon` a 19 funciones sensibles más (racional :5-13: el default-privilege de Supabase otorga EXECUTE explícito a `anon` a cada función nueva; en un rebuild fresco quedaban 42 anon-ejecutables vs 23 de prod).
4. `20260621140000:32-75`: bucle que revoca `service_role` de **toda** función de `public` fuera de una keep-list de 23 firmas (helpers RLS, ciclo de invitaciones, `fn_norm_*`, `get_*_org`) — fidelidad "staging=prod", no seguridad (:13-15).
5. `20260621170000:361-372`: para la nueva `guardar_proyecto` reproduce el baseline exacto: `REVOKE ALL ... FROM PUBLIC, anon, service_role; GRANT EXECUTE ... TO authenticated` — con el racional de que `REVOKE FROM PUBLIC` no basta por los grants explícitos.

Invariante declarado: **baseline de ACL de funciones sensibles = `{authenticated, postgres}`**; anon-ejecutables solo el set de 23 (flujos de invitación fail-closed por `auth.uid() IS NULL` + helpers de RLS que no pueden revocarse a anon sin romper la evaluación de policies, `20260617144834:18-33`).

---

## 5. Cruce frontend ↔ esquema

**RPCs**: el frontend llama 32 RPCs distintas (`grep -o "rpc('[^']*'" frontend/src -r | sort -u | wc -l` → 32); **las 32 existen en SQL** (cruce por script Python: lista vacía de faltantes). En dirección inversa, funciones no-helper que **nadie llama desde el frontend**: `eliminar_proyecto`, `restaurar_proyecto`, `exportar_herramienta`, `procesar_eliminaciones_vencidas` (esta última es legítima: la invoca pg_cron, `20260616150836:2-6`).

**Tablas**: el frontend toca 25 tablas `public` por `.from()` directo (lista del grep en §corpus: memberships, projects, user_profiles, locations, legal_templates, legal_documents, contacts, companies, organizations, organization_profile, user_bank_accounts, profile_permissions, invitation_rebind_requests, contact_talent_profiles, user_notifications, tax_rates, project_client_payments, project_cargos, plan_catalog, permission_profiles, organization_branding, org_invitations, data_consents, cookie_consents, analytics_events) + 2 buckets de storage (`adjuntos-gastos`, `fotos-locaciones`) + 27 tablas más vía selects anidados: las 23 hijas de proyecto en `_dalProyectoSelect()` (dal.js:1254-1279, incluye `departments(nombre)`, `project_functions(nombre)`, `task_comments`, `task_attachments`) y las hijas de BD en dal.js:197 (`contact_roles(*), contact_bank_accounts(*), contact_talent_profiles(*), contact_companies(*)`) y :200 (`company_relationships(*)`).

**Tablas del esquema jamás nombradas en `frontend/src`** (script Python, 15): `app_config`, `default_*` (×5), `notification_send_recipients`, `notification_sends`, `notification_templates`, `plan_features`, `project_members`, `scheduled_account_deletions`, `user_tool_archive`, `user_tool_documents`, `user_tool_versions`. De estas, tienen consumidor server-side: `app_config` (funciones DEFINER), `default_*` (`seed_permisos_organizacion`/`provisionar_organizacion`), `plan_features` (`auth_plan_permite`), `scheduled_account_deletions` (`solicitar/cancelar_eliminacion_cuenta` + cron). **Sin consumidor en ninguna capa**: `project_members` (solo DDL: :3564, :4399-4405, :5365) y el trío `notification_sends/recipients/templates` (única referencia funcional: `get_send_org` :943, que solo la lee para RLS). `user_tool_*` solo lo tocan `exportar_herramienta` y sus triggers — y nadie llama `exportar_herramienta`.

---

## Hallazgos

**H1 (seguridad, alta): el soft-delete de proyectos desde el cliente elude el permiso `eliminar_proyecto` a nivel de BD.** `frontend/src/modules/kanban.js:320-323` borra con UPDATE directo: `sb.from('projects').update({ deleted_at: now, updated_at: now }).eq('id', id).eq('organization_id', ORG_ID)`. Bajo RLS eso lo autoriza `b_projects_upd` (dump :5956), que exige `auth_nivel('info_proyecto')='E'` — no `eliminar_proyecto`. La policy `b_projects_del` (:5944, `eliminar_proyecto='E'`) solo cubre `DELETE` SQL, que nunca ocurre. Las RPC que sí exigen `rpc_assert_nivel('eliminar_proyecto','E',v_org)` — `eliminar_proyecto` (:668) y `restaurar_proyecto` (:2033) — existen, fueron endurecidas (`20260617144834:68-72`) y **el frontend no las llama** (grep `rpc('eliminar` → 0). Consecuencia: un perfil Ejecutivo (código 2: `info_proyecto='E'`, `eliminar_proyecto='none'`, seed `20260616170000:76`) puede marcar `deleted_at` vía PostgREST; el gate `authNivel('eliminar_proyecto') !== 'E'` de kanban.js:280 es solo UX.

**H2 (seguridad/contrato, media): "externo no lee `contacts`" es convención, no invariante.** Detalle en §3.2. Ninguna policy consulta `memberships.tipo`; `invitar_a_organizacion` solo veta perfiles 1 y 8 para externos (`20260617160000:164-166`), y `invitaciones.js:27-34` permite pasar cualquier `perfilCodigo` de la UI. Un externo invitado con perfil 3-6 lee la tabla `contacts` completa de la org (RUT, banco vía `contact_bank_accounts`, etc.), contradiciendo el comentario de dal.js:248-252 y el propósito del "lente" `personas_de_mis_proyectos`.

**H3 (mínimo privilegio, baja-media): `GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ... TO anon` (y `service_role`) en las 72 tablas del dump** (72 líneas, `grep -c 'GRANT .* ON TABLE .* TO "anon"' 20260616150834_remote_schema.sql` → 72; ej. :6699, :6805) y replicado a mano en `gasto_comments` (`20260628130000:70-71`). `TRUNCATE` **no** está sujeto a RLS. Mitigante: PostgREST no expone TRUNCATE, así que no es explotable con la anon key por la API estándar; aun así contradice la doctrina de endurecimiento del propio repo y quedaría explotable ante cualquier vía SQL futura con esos roles.

**H4 (fidelidad, baja): los 6 RPC nuevos `archivar_*/restaurar_*` revocan `PUBLIC, anon` pero no `service_role`** (`20260629120000:110-115`), pese a que la doctrina establecida en `20260621170000:361-371` y `20260621140000` exige baseline `{authenticated, postgres}` y advierte que el grant explícito de `service_role` sobrevive al `REVOKE FROM PUBLIC`. En un rebuild fresco estas 6 funciones divergen de la keep-list de 23.

**H5 (contrato, media): fallos silenciosos por sección en `guardar_proyecto` y `guardar_operaciones_4b/4c`.** En `guardar_proyecto`, si el proyecto existe y el nivel no es 'E', la sección se salta sin error (`if (v_header is not null) and ((not v_existe) or v_n_info = 'E')`, `20260621180000:78`; ídem :145, :165, :207, :292) y el RPC retorna éxito — el autosave del cliente limpia las marcas dirty creyendo que persistió. Lo mismo con `responsables` en 4b para perfiles ∉ (1,2) (`20260628130000:124-131`) y con tareas/señales en 4c (:1216, :1245). Contrasta con `guardar_cargos`/4a/4e, que fallan ruidosamente con `takeos_auth`.

**H6 (deuda, media): la "Pasada 2" del versionado no existe.** Dentro de `guardar_proyecto`, asignaciones/finanzas(comisiones/riesgos/extras)/cotización/versiones siguen en DELETE-masivo+reinsert sin versión (comentarios "Se convierte(n) en Pasada 2", `20260621180000:141-144` y :161-163); dos sesiones editando finanzas del mismo proyecto se siguen pisando (el key-guard solo protege lo *no* enviado). Igual para 4a/4b/4c/4e y `guardar_cargos`/`guardar_pagos_cliente`: cero concurrencia optimista fuera de cabecera+presupuesto.

**H7 (código muerto): RPCs y tablas huérfanas.** `eliminar_proyecto`/`restaurar_proyecto` (reemplazadas de facto por H1), `exportar_herramienta` + tablas `user_tool_documents/versions/archive` + triggers (`20260616150835:30-31`) + bucket `herramientas-personales` con 4 policies `hp_*` (:7281-7315): módulo "herramientas personales" completo sin un solo consumidor en `frontend/src` (grep repo-wide → solo migrations). `project_members` (tabla sin lector ni escritor en ninguna capa). `notification_sends/recipients/templates` sin escritor en SQL ni frontend. `rpc_assert_cupo_colaborador` deprecada explícitamente (`20260617160000:218-219`) pero conservada.

**H8 (documentación desactualizada): el COMMENT de `plan_catalog` afirma "GROUNDWORK (sin enforcement aun) ... No esta cableado a auth_nivel"** (dump, tras :3170), pero el enforcement existe y está vivo: `rpc_assert_cupo_proyecto` (:2092-2102) lee `max_proyectos_activos`, `guardar_cargos` lee `max_colaboradores` (`20260617160000:75-81`), y `plan_features` se consulta en cada `rpc_assert_plan` (:2142-2149).

**H9 (contrato asimétrico menor): `guardar_operaciones_4a` no es key-guarded** — a diferencia de `gastoComments` en 4b, un payload sin `planRodaje`/`hojaLlamado` como objeto **borra** `project_shooting_plan`/`project_call_sheet` (dump :1075-1089). Hoy es inocuo porque el cliente siempre manda ambos campos (null si vacíos, dal.js:1691-1699), pero cualquier cliente parcial futuro borraría la hoja de llamado sin querer.