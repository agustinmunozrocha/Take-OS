# Informe técnico — Persistencia, sincronización y multi-tenancy · TakeOS (`frontend/src/`)

Verificado sobre el árbol de trabajo en rama `etapa4-integracion` (commit HEAD `4c8067b`). Todas las cifras están contadas con comandos (se indica cuál); todas las firmas son copias literales.

Los dos dueños del tema son: **`frontend/src/modules/persistencia-local.js`** (636 líneas, `wc -l`) — persistencia LOCAL (autosave/snapshots/undo) — y **`frontend/src/modules/dal.js`** (1899 líneas, `wc -l`) — persistencia REMOTA (Supabase). La costura declarada entre ambos es doble (persistencia-local.js:4-6): `markDirty → dalTouchProyecto` y `undo/redo → _conflictoBannerHide`.

---

## 1. Persistencia local (`frontend/src/modules/persistencia-local.js`)

### 1.1 Autosave (airbag en localStorage)

- Clave: `const LS_KEY = 'takeos_autosave_v1';` (persistencia-local.js:44). Formato: `const SAVE_FORMAT_VERSION = 5;` (:43).
- **Qué guarda** — `function buildSaveObject()` (:58-81) serializa el estado COMPLETO en un único JSON: `{ app:'TakeOS', format:'takeos-save', version, savedAt, projects: PROJECTS, trash: TRASH, empresaPerfil: EMPRESA_PERFIL, bdContactos: BD_CONTACTOS, bdEmpresasById: BD_EMPRESAS_BYID, bdLoc: BD_LOC, bdLegal: BD_LEGAL, bdLegalTpl: BD_LEGAL_TPL, bdPersonas, bdEmpresas, bdTalentos }` (las 3 últimas son proyecciones legacy para clientes V7.2.x, :75-79).
- **Escritor**: `export function autosaveNow()` (:488-495): `localStorage.setItem(LS_KEY, JSON.stringify(buildSaveObject()))` dentro de try/catch; en fallo llama `_persisAvisarFallo(...)` (:481-487), que avisa **una sola vez por sesión** (`_persisFalloAvisado`, :480) — decisión documentada como "Hallazgo 🔴 de la Fase 0" (antes el fallo era tragado por ~30 llamadores).
- **Timer/debounce**: `function scheduleAutosave()` (:496-499) — `setTimeout(autosaveNow, 2000)` con `clearTimeout` previo (`_autosaveTimer`, :45). **2000 ms**.
- **Triggers** de `export function markDirty()` (:506-514):
  1. Delegación global en boot: `document.addEventListener('change', markDirty, true);` y `document.addEventListener('input', () => { if (STATE.dirty) return; markDirty(); }, true);` (boot.js:678-679).
  2. Llamadas directas: 182 apariciones de `markDirty()` en `src/` (`grep -rn "markDirty()" frontend/src | wc -l` → 182; incluye la definición y comentarios), repartidas p.ej. plan-rodaje.js (36), presupuesto-cotizacion.js (34), locaciones.js (24), gastos.js (19) (`grep -c`).
  3. Airbag de salida: `window.addEventListener('beforeunload', () => { if (STATE.dirty) autosaveNow(); });` (boot.js:681).
- **Cadena interna de markDirty** (:506-514): `STATE.dirty = true` → clase `is-dirty` en `#saveBtn` → `_syncDirtyChip()` → `recordUndoPoint()` → `scheduleAutosave()` → `if (STATE.currentProject) dalTouchProyecto(STATE.currentProject)` (costura a Supabase, :513).
- `autosaveNow()` tiene 42 sitios de llamada (`grep -rn "autosaveNow()" frontend/src | wc -l` → 42).
- **Invariante de lectura**: el autosave es hoy **write-only para el estado** — la única lectura de `LS_KEY` es `export function restoreLocalLocPhotos()` (:93-103), que reinyecta SOLO `bdLoc[].fotos` (las fotos base64 no viajan por la nube; blindaje V8.3.3, :83-92). Ver Hallazgo H1.
- Detección segura: `function hasLS()` (:48-55) con probe `'__takeos_test__'` (set+remove).

### 1.2 Snapshots anti-destrucción

- Clave `const SNAP_KEY = 'takeos_snapshots';` y tope `const SNAP_MAX = 5;` (:253-254). Estructura: array JSON de `{ label, createdAt, json: JSON.stringify(buildSaveObject()) }` — cada snapshot es el OS COMPLETO serializado (`export function pushSnapshot(label)`, :270-280). FIFO: `list.unshift(snap); while (list.length > SNAP_MAX) list.pop();` (:277-278).
- Se crean automáticamente antes de operaciones destructivas: `pushSnapshot('Antes de cargar OS ' + file.name)` (:227), `pushSnapshot('Antes de revertir a: ' + snap.label)` (:302), `pushSnapshot('Antes de reemplazar proyecto: ' + nombre)` (:448).
- Revertir: `function restoreSnapshot(index)` (:281-308) → modal de confirmación → `applyLoadedState(obj)` (:116-147), que reemplaza en sitio PROJECTS/TRASH/BDs (mutación `length=0`+push para no romper referencias), rehidrata con `hydrateContactStore(obj)` (lib/modelo.js), navega al Control Room y `clearDirty()`. El fallo de escritura de snapshots avisa vía `_persisAvisarFallo` (:268).
- UI: `export function openSnapshotsModal()` (:316-347); acciones delegadas `registrarAcciones('snap', { revertir…, borrar… })` (:626-629).

### 1.3 Undo/Redo (⌘Z / ⌘⇧Z)

- Estado del mecanismo (:21-24): `let UNDO_STACK = []; let UNDO_BASELINE = null; const UNDO_MAX = 30; let REDO_STACK = [];` — **límite 30 niveles**, por snapshot JSON del **proyecto completo** (`{ id, snap: JSON.stringify(p) }`).
- Baseline: `export function captureUndoBaseline()` (:523-528) — vacía la pila y captura el proyecto actual; se llama al entrar a un proyecto (`captureUndoBaseline();` en kanban.js:222, dentro de `navigateToProject`).
- Punto de undo: `function recordUndoPoint()` (:529-540) — corre en cada `markDirty()`; solo si `STATE.currentView === 'project'` y el baseline es del mismo proyecto; empuja el baseline anterior, recorta a `UNDO_MAX` y **una edición nueva invalida el redo** (`REDO_STACK = [];`, :536).
- Atajos (boot.js:61-75): ⌘/Ctrl+Z → `undoLast()`; ⌘/Ctrl+Shift+Z → `redoLast()`; ambos se inhiben si `document.activeElement` es INPUT/TEXTAREA/contentEditable (deshacer nativo del campo).
- `export function undoLast()` (:574-596) / `export function redoLast()` (:597-616): restauran el snapshot en `PROJECTS[idx]` y `STATE.currentProject`, marcan dirty, reprograman autosave y re-renderizan (`navigateToModule(STATE.currentModule)`).
- **Dos correcciones de concurrencia post-restauración** (Pasada 1):
  - `function _reconcileVersionsFromLive(restored, live)` (:553-567): conserva del estado VIVO la versión por fila (`clientUuid → version` en `servicios/gastos/equipos/talentos`) y la línea base de cabecera (`restored._headerVersion = live._headerVersion; restored._budgetPendingDeletes = (live._budgetPendingDeletes||[]).slice(); restored._snap = live._snap;`) — evita conflicto falso al reenviar contenido viejo con versión vieja.
  - `function _resetFlagsRuntime(project)` (:568-573): apaga `_saving/_resaveQueued/_autosaveSuspendedByConflict/_conflictoModalAbierto` y llama `_conflictoBannerHide()` — sin esto un undo tomado durante un guardado restauraría `_saving=true` y trabaría el autosave (deadlock documentado :545-547).
- Reset multi-org: `window._persisResetOrg = function () { UNDO_STACK = []; REDO_STACK = []; UNDO_BASELINE = null; if (_autosaveTimer) { clearTimeout(_autosaveTimer); _autosaveTimer = null; } }` (:25-28) — el historial no cruza organizaciones y se cancela el autosave de 2 s para no pisar el airbag con el estado recién vaciado.

### 1.4 Export / Import (.json)

- `export function exportSave()` (:150-169): descarga `takeos_save_YYYY-MM-DD_HHMM.json` + `autosaveNow()` + `clearDirty()`.
- `export function importSaveFromInput(input)` (:186-241): **aditivo** (V10.5.1, `mergeAddProjectsFromSave`, :175-185 — solo agrega proyectos con id nuevo); gateado a `gancho('_puedeModoAdmin')()` **y** `STATE.adminMode` (:191-197); snapshot previo automático.
- Por proyecto: `function exportSingleProject(projectId)` (:368-399) y `export function importSingleProjectFromInput(input)` (:401-477), formato `takeos-project` v1; el reemplazo por id existente crea snapshot previo (:448).
- Ganchos definidos por el módulo (:632-636): `autosaveNow`, `exportSave`, `exportSingleProject`, `markDirty`, `openSnapshotsModal`.

### 1.5 TODAS las claves de Web Storage (`grep -rn "localStorage\|sessionStorage" frontend/src --include="*.js"`)

**localStorage (13 claves):**

| Clave | Módulo (def/uso) | Contenido |
|---|---|---|
| `takeos_autosave_v1` | persistencia-local.js:44 (write :491; read solo fotos :95) | JSON completo `buildSaveObject()` (OS entero) |
| `takeos_snapshots` | persistencia-local.js:253 (:259/:267) | Array ≤5 de `{label, createdAt, json}` |
| `takeos_theme` | lib/ui.js:318 (`THEME_KEY`; :320/:330) | `'dark'`\|`'light'` |
| `takeos_notif_config_v1` | notificaciones.js:205 (`NOTIF_CFG_KEY`; :228/:248) | `{empresa, remitente, linkFormulario, templates[]}` del motor de correos |
| `takeos_budget_colw` | presupuesto-cotizacion.js:1043/1057/1112 | Anchos de columna por sección del presupuesto (`_BUDGET_COLW`) |
| `takeos_usuario_actual` | boot.js:33-34 (write/boot-read), :93 (logout), dal.js:493 (limpieza cross-sesión) | Nombre visible cacheado del usuario |
| `takeos_usuario_uid` | dal.js:490/513; boot.js:93 | UID de la sesión que cacheó ese nombre (anti nombre-ajeno, V11.9.3 BUG-6) |
| `takeos_auth_at` | boot.js:392/423/433/438/538/93 | Timestamp (ms) del último login explícito — habilita la "sesión breve" |
| `takeos_auth_uid` | boot.js:393/424/433/438/538/93 | UID del login explícito (la sesión restaurada solo vale para el mismo uid) |
| `takeos_org_activa` | boot.js:128 (`_ORG_LS_KEY`) / :182 | UUID de la última org activa — **solo se escribe, nunca se lee** (Hallazgo H8) |
| `takeos_esp_onb` | espacio.js:169/187 | `'1'` = onboarding del Panel Personal ya visto |
| `takeos_cargos_<ORG_ID>_<projectId>` | cargos.js:45 (`function _cargosKey(project) { return 'takeos_cargos_' + ORG_ID + '_' + project.id; }`); leída/borrada en dal.js:44/48 | Legacy V11.2: cargos provisionales; migración one-shot a `project_cargos` si la tabla está vacía |
| `__takeos_test__` | persistencia-local.js:50-52 | Probe de disponibilidad de LS (set+remove inmediato) |

**sessionStorage (5 claves):**

| Clave | Módulo | Contenido |
|---|---|---|
| `takeos_inv_pendiente` | boot.js:80 (captura de `?invitacion=`), :443/:612; invitaciones.js:65 | Token de invitación — sobrevive el viaje OAuth a Google |
| `takeos_ir_proyecto` | espacio.js:208; consumida en dal.js:1336-1338; boot.js:576 | Id de proyecto destino (salto directo desde el Panel Personal, V11.9.7) |
| `takeos_sin_veil` | config.js:43; boot.js:429/691 | `'1'` = suprimir la cortina de arranque (navegación interna a `?espacio=1`) |
| `takeos_last_view` | kanban.js:45 (`_LV_KEY`), write :63-72 (`_lastViewSave`: `{org: ORG_ID, view, projectId, module}`), read :75 (`_lastViewLeer`) | Restauración de vista tras F5, validada contra `ORG_ID` en dal.js:1346 |
| `takeos_cta_prod_dismissed` | plan-limites.js:20 (`_CTA_PROD_DISMISS_KEY`; :23/:26) | `'1'` = CTA "¿Tienes una productora?" descartado por sesión |

---

## 2. Data Access Layer (`frontend/src/modules/dal.js`, 1899 líneas)

Cliente: `sb` de `frontend/src/lib/supabase.js` — `export let sb = null;` (supabase.js:15), inicializado por `export function supabaseInit()` (:17-25) con `import.meta.env.VITE_SUPABASE_URL/VITE_SUPABASE_KEY`; espejado en `window.sb`. dal.js consume `sb` como global (no lo importa).

### 2.1 Inventario COMPLETO de la API pública (34 exports; `grep -n "^export" frontend/src/modules/dal.js`)

| Export (firma real) | Línea | Rol |
|---|---|---|
| `export async function dalCargarCargos(project)` | 33 | Lee `project_cargos` (+ migración one-shot desde localStorage) |
| `export async function dalGuardarCargos(project)` | 68 | RPC `guardar_cargos` (estado completo) |
| `export async function dalCargarTopeColaboradores()` | 91 | `organizations.plan` → `plan_catalog.max_colaboradores`; cache por org (`_TOPE_COLAB/_TOPE_COLAB_ORG`) |
| `export const _DAL_TIPOCUENTA_LABEL = {...}` | 116 | Mapa código→etiqueta cuentas bancarias |
| `export function _dalBancoNombre(codigo)` | 118 | Código SBIF → nombre banco |
| `export async function dalBootContactos()` | 234 | Tanda 1: `contacts`+`companies` (con satélites embebidos) → stores |
| `export async function dalBootPersonasExternos()` | 256 | RPC `personas_de_mis_proyectos` (lente para tipo `'externo'`) |
| `export async function dalBootLocaciones(opts)` | 330 | `locations` → `BD_LOC` + `restoreLocalLocPhotos()` |
| `export async function dalBootLegal(opts)` | 390 | `legal_documents`+`legal_templates` |
| `export async function dalBootPerfil(opts)` | 455 | `organization_profile`+`organizations.nombre`+`organization_branding` (merge branding⊂profile, :443) |
| `export async function dalResolveIdentidad()` | 476 | Sesión → `DAL_SESSION_UID/EMAIL`; nombre real desde `user_profiles` (fallback: match por email en `BD_CONTACTOS`) |
| `export async function dalLoadPermisos()` | 541 | `memberships` (+`permission_profiles` embebido) → `TAKEOS_PERFIL`; `profile_permissions` → `TAKEOS_ACCESO` |
| `export async function dalGuardarContacto(c)` | 673 | insert/update `contacts` + reemplazo total de satélites |
| `export async function dalGuardarEmpresa(e)` | 702 | insert/update `companies` + `company_relationships` |
| `export async function dalFinishBulkImport(contactIds, companyIds)` | 748 | Cierre de import .xlsx: `dalBulkSyncBD` en serie |
| `export function _dalContactoSaveSoon(id)` | 765 | Debounce 900 ms (`_dalSaveTimers['c:'+id]`) |
| `export function _dalEmpresaSaveSoon(id)` | 770 | Debounce 900 ms (`'e:'+id`) |
| `export async function dalGuardarLocacion(l)` | 792 | insert/update `locations` (fotos NO viajan) |
| `export function _dalLocacionSaveSoon(locId)` | 812 | Debounce 900 ms (`'loc:'+locId`) |
| `export async function dalEliminarLegalDoc(docId)` | 856 | delete `legal_documents` |
| `export async function dalEliminarLegalTpl(tplId)` | 886 | delete `legal_templates` |
| `export function _dalLegalDocSaveSoon(docId)` | 891 | Debounce 900 ms (`'legaldoc:'+docId`) |
| `export function _dalLegalTplSaveSoon(tplId)` | 896 | Debounce 900 ms (`'legaltpl:'+tplId`) |
| `export function _dalPerfilSaveSoon()` | 916 | Debounce 900 ms (`'perfil'`) → upsert `organization_profile` |
| `export const DAL_KNOWN_PROJECT_IDS = new Set();` | 931 | Set insert-vs-update (espejado en `window`) |
| `export function _dalProyectoPartes(p)` | 1136 | Fila PostgREST (select anidado) → partes canónicas del cliente |
| `export function _dalFusionarProyecto(target, partes)` | 1205 | Fusión no destructiva + línea base de concurrencia (`_headerVersion/_snap/_budgetPendingDeletes`, :1244-1249) |
| `export async function dalLoadProyectos(soloBorrados)` | 1281 | `projects` con `_dalProyectoSelect()` (select de ~28 relaciones embebidas, :1254-1279) |
| `export async function dalBootProyectos()` | 1313 | Orquesta carga+fusión+restauración de vista (`takeos_ir_proyecto`/`takeos_last_view`) |
| `export function _conflictoBannerHide()` | 1684 | Quita el banner de conflicto |
| `export function dalResetOrg()` | 1855 | Reset del estado interno del DAL + incremento de época |
| `export function dalTouchProyecto(project)` | 1865 | Encola proyecto sucio + debounce 1500 ms |
| `export async function dalFlushProyectos()` | 1872 | Flush secuencial: core → 4a → 4b → 4c → 4e |

No exportadas pero centrales: `dalGuardarProyecto(project)` (:1539), `_dalProyectoPayload(project)` (:1458), `_dalAdoptarRespuesta(project, meta, data)` (:1588), `manejarConflicto(e, project)` (:1612), `dalReloadProyecto(id)` (:1297), `dalGuardarPerfil()` (:904), `dalGuardarLegalDoc/Tpl` (:836/:866), `_dalReplaceChildren(table, fk, id, rows)` (:662-670), `dalGuardarOperaciones4a/4b/4c/4e` (:1701/:1761/:1800/:1830).

### 2.2 Tablas de Supabase tocadas (`grep -rho "\.from('[^']*'" frontend/src --include="*.js" | sort -u`, excluyendo `sb.storage.from`)

**25 tablas con literal directo** (archivo(s) que las tocan):

`analytics_events` (plan-limites.js:21) · `companies` (dal.js, bd.js) · `contacts` (dal.js, bd.js) · `contact_talent_profiles` (dal.js:691-692, upsert/delete directo) · `cookie_consents` (config.js) · `data_consents` (config.js) · `invitation_rebind_requests` (notificaciones.js) · `legal_documents` (dal.js) · `legal_templates` (dal.js) · `locations` (dal.js, bd.js) · `memberships` (boot.js:614, dal.js:546, config.js, cargos.js, espacio.js) · `org_invitations` (cargos.js) · `organization_branding` (dal.js:429) · `organization_profile` (dal.js:423/:907, config.js) · `organizations` (dal.js:95/:424, config.js) · `permission_profiles` (config.js) · `plan_catalog` (dal.js:99) · `profile_permissions` (dal.js:563, cargos.js) · `project_cargos` (dal.js:37) · `project_client_payments` (gastos.js:915) · `projects` (dal.js:1285/:1300, kanban.js, info-proyecto.js, espacio.js) · `tax_rates` (lib/rates.js) · `user_bank_accounts` (perfil-onboarding.js) · `user_notifications` (notificaciones.js) · `user_profiles` (dal.js:506, boot.js:654, perfil-onboarding.js).

**Además, con nombre variable** (no aparecen en el grep literal):
- `_dalReplaceChildren(table, fk, id, rows)` (dal.js:662-670) escribe delete+insert sobre `contact_roles`, `contact_bank_accounts`, `contact_companies` (dal.js:687-689) y `company_relationships` (dal.js:716).
- El respaldo admin `_supaDumpTable(tabla)` (admin.js:336-344) lee `select('*')` paginado (PAGE=1000, tope 60k filas) sobre las 38 tablas de `SUPA_BACKUP_TABLES` (admin.js:314-335), incluidas las de solo-lectura-embebida del cliente (`budget_line_items`, `project_quotation`, `quotation_offers`, `quotation_versions`, `project_shoot_days`, `project_shooting_plan`, `project_call_sheet`, `project_locations`, `project_crew_extra`, `project_external_crew`, `project_section_responsibles`, `project_operations`, `project_op_budgets`, `project_tasks`, `task_comments`, `task_attachments`, `project_signals`, `project_documents`, `departments`, `project_functions`, `project_assignments`, `project_financials`, `project_commissions`, `project_risks`, `project_income_extras`, `project_cancellations`, `project_cancellation_reasons`, `cancellation_reasons`, …).
- Vía select embebido de PostgREST (`_dalProyectoSelect()`, dal.js:1254-1279) el cliente LEE ~28 tablas hijas de `projects` (incluye `project_commercial` y `gasto_comments`) cuya ESCRITURA va solo por RPC.

### 2.3 RPCs llamadas (`grep -rn "\.rpc('" frontend/src --include="*.js"` → 34 líneas, **32 RPCs distintas**)

| RPC | Sitio | Propósito |
|---|---|---|
| `guardar_proyecto` | dal.js:1551 | Núcleo: cabecera+finanzas+presupuesto+cotización, payload DIFF, atómico |
| `guardar_operaciones_4a` | dal.js:1705 | rodajes+plan+hoja (estado completo) |
| `guardar_operaciones_4b` | dal.js:1765 | locaciones+crew+responsables+asistentes+gastosOp (estado completo; `gastoComments` se omite si no está cargado, :1750-1757) |
| `guardar_operaciones_4c` | dal.js:1804 | tareas+señales (estado completo) |
| `guardar_operaciones_4e` | dal.js:1834 | documentos (solo rutas Storage) |
| `guardar_cargos` | dal.js:77 | Cargos (estado completo; server-side impone tope de plan) |
| `personas_de_mis_proyectos` | dal.js:261 | Lente de personas para externos (4 campos visibles) |
| `guardar_pagos_cliente` | gastos.js:945 | Pagos cliente (estado completo) |
| `archivar_contacto` / `archivar_empresa` / `archivar_locacion` | bd.js:705/724/743 | Soft-delete |
| `restaurar_contacto` / `restaurar_empresa` / `restaurar_locacion` | bd.js:791/796/801 | Undelete |
| `marcar_notificaciones_leidas` | notificaciones.js:99 | Campana |
| `resolver_rebind` | notificaciones.js:156 | Aprobación de re-vínculo de invitación |
| `invitar_a_organizacion` / `reclamar_invitacion` / `consentir_invitacion` / `cerrar_invitacion` | invitaciones.js:32/68/156/167,193 | Ciclo de invitación |
| `asignar_cargo_a_miembro` | cargos.js:387 | Vincula cargo↔miembro |
| `mis_invitaciones` | boot.js:624 | Bandeja del Panel Personal |
| `cancelar_invitacion` / `transferir_administracion` / `invitaciones_de_organizacion` / `provisionar_organizacion` / `exportar_mis_datos` / `revocar_consentimiento` / `mis_organizaciones_como_unico_admin` / `solicitar_eliminacion_cuenta` / `cancelar_eliminacion_cuenta` / `guardar_consentimiento_cookies` | config.js:417/632/648/1278/1723/1815/1856/1904/1944/2031 | Administración/privacidad |

### 2.4 Buckets de Storage (5; `grep -rn "storage.from\|STORAGE_BUCKET" frontend/src`)

| Bucket | Constante | Módulo | Uso |
|---|---|---|---|
| `fotos-locaciones` | `STORAGE_BUCKET_FOTOS` (locaciones.js:352) + literal en lib/ui.js:441 | locaciones.js:369/382/430/447/464; ui.js:441 | upload/signedUrl(3600 s y 600 s)/remove |
| `documentos-proyecto` | `STORAGE_BUCKET_DOCS` (documentos.js:120) | documentos.js:130/177/199 | upload/signedUrl/remove |
| `documentos-legales` | `STORAGE_BUCKET_LEGAL` (legal.js:58) | legal.js:64/71/820 | upload PDF/signedUrl/remove |
| `adjuntos-tareas` | `STORAGE_BUCKET_ADJUNTOS` (tareas.js:199) | tareas.js:205/226 | upload/remove (ruta persiste en `task_attachments.storage_path`) |
| `adjuntos-gastos` | literal | gastos.js:455/488/769/805 | upload/signedUrl/remove |

### 2.5 Realtime

**Cero canales**: `grep -rn "\.channel(\|postgres_changes\|realtime" frontend/src --include="*.js"` no devuelve nada. No hay suscripciones; la concurrencia se resuelve por versionado optimista en el RPC (`TAKEOS_CONFLICT`, §3.4) y la "notificación" es polling propio del módulo notificaciones sobre `user_notifications`.

---

## 3. Estrategia de sincronización

### 3.1 Flags `*_SOURCE` (fuente de datos con confirmación de lectura)

Declarados en lib/state.js:60-64:
```js
export let CONTACTS_SOURCE  = 'pending';
export let LOCATIONS_SOURCE = 'pending';
export let LEGAL_SOURCE     = 'pending';
export let PERFIL_SOURCE    = 'pending';
export let PROJECTS_SOURCE  = 'pending';
```
Única vía de escritura: `export function setSource(cual, v)` (state.js:237-243). Solo hay 2 valores en uso: `'pending'` y `'supabase'` — el paso `pending → supabase` ocurre exclusivamente tras una **lectura exitosa** (`dalApplyTanda1` dal.js:220, `dalApplyLocaciones` :328, `dalApplyLegal` :388, `dalApplyPerfil` :452, `dalBootProyectos` :1318/:1331) y es one-way dentro de una org (vuelve a `'pending'` solo en el reset de `_setOrgActiva`, boot.js:154-156).

**Invariante fail-safe** (comentario state.js:57-58): *"sin lectura confirmada NO se escribe"*. Todos los escritores lo respetan como guarda de entrada, p. ej.: `if (!sb || CONTACTS_SOURCE !== 'supabase' || !c || !c.id) return { ok: false, skipped: true };` (dal.js:674), `if (LOCATIONS_SOURCE !== 'supabase' || !locId) return;` (:813), `if (PROJECTS_SOURCE !== 'supabase' || !project || !project.id) return;` (:1866). Caso especial documentado en dal.js:1318: una org **sin proyectos** igualmente marca `setSource('projects','supabase')` — "la nube respondió", sin esto el flag quedaba `'pending'` y nada sincronizaba.

Nota: `window.__TAKEOS_DATA_SOURCE = 'supabase'` (dal.js:244) es un marcador informativo sin lectores en `src/` (grep → solo esa línea).

### 3.2 Debounces de guardado

- **`const _dalSaveTimers = {};`** (dal.js:764) — mapa único con claves con prefijo por entidad, **todas a 900 ms**:
  - `'c:'+id` contactos (:765-769), `'e:'+id` empresas (:770-774), `'loc:'+locId` locaciones (:812-816), `'legaldoc:'+docId` (:891-895), `'legaltpl:'+tplId` (:896-900), `'perfil'` singleton (:916-920).
- **Proyectos**: debounce colectivo — `const _dalDirtyProjects = new Set(); let _dalProyFlushTimer = null;` (:1844-1845); `dalTouchProyecto` (:1865-1871) agrega el id y reprograma `setTimeout(dalFlushProyectos, 1500)` → **1500 ms**.
- **Airbag local**: 2000 ms (§1.1). Jerarquía real por edición dentro de un proyecto: RPC a los 1,5 s; localStorage a los 2 s.

### 3.3 Flush y payload diferencial

`dalFlushProyectos()` (:1872-1890) drena el set y por proyecto ejecuta EN ORDEN: `dalGuardarProyecto` (core) → `guardar_operaciones_4a` → `4b` → `4c` → `4e`; un solo toast "Sincronización parcial" si cualquiera falla (:1886-1888). Retornos tipados de `dalGuardarProyecto`: `true | false | 'plan' | 'conflict'` — `'plan'`/`'conflict'` cortan las operaciones 4x de ese proyecto (:1881).

`dalGuardarProyecto` (:1539-1582):
- **Mutex por proyecto**: `if (project._saving) { project._resaveQueued = true; return true; }` (:1545) con re-disparo en `finally` (:1576-1581).
- **No-op**: `_dalProyectoPayload` (:1458-1537) devuelve `null` si nada cambió → no se llama al RPC (:1547).
- **Diff**: cabecera solo si `project._headerDirty || esNuevo` (versionada como unidad, `projects.version`); presupuesto por fila: solo filas con `r._dirty` o nuevas (`r.version == null`) no vacías, más `deletes` desde `project._budgetPendingDeletes` (poblado por `_budgetQueueDeletes`, presupuesto-cotizacion.js:58-65, con `{clientUuid, version}`); secciones no migradas (asignaciones/finanzas/cotización/versiones) solo si su snapshot JSON difiere de `project._snap` (`_snapSecciones`, :1442-1450) — "el RPC, por presencia de clave, no toca lo que no se manda" (:1396-1397).
- **Marcas granulares**: productores en info-proyecto.js — `export function _markRowDirty(row) { if (row) { row._dirty = true; row._dirtySeq = (row._dirtySeq || 0) + 1; } return row; }` (:369-372) y `function _markHeaderDirty(project)` (:373-375). Las filas default de proyecto nuevo nacen `_dirty:true, _dirtySeq:1, version:null` (lib/modelo.js:305-307).
- **Adopción de respuesta** `_dalAdoptarRespuesta` (:1588-1606): la versión nueva se adopta SIEMPRE; la marca de sucio se limpia SOLO si `_dirtySeq`/`_headerDirtySeq` no cambió durante el viaje del RPC (no pierde una segunda edición); los deletes confirmados se filtran por `clientUuid+'@'+version`; `_snap` se re-baselinea con LO ENVIADO.
- Red de seguridad de identidad de fila: `if (!r.clientUuid) r.clientUuid = _clientUuid();` (:1497).

### 3.4 Resolución de conflictos (`TAKEOS_CONFLICT`)

- El RPC `guardar_proyecto` lanza `'TAKEOS_CONFLICT:{seccion,ids}'`; el cliente lo parsea con `var m = raw.match(/TAKEOS_CONFLICT:\s*(\{[\s\S]*\})/);` en `function manejarConflicto(e, project)` (dal.js:1612-1623). Único punto de aparición en `src/` (`grep -rn "TAKEOS_CONFLICT"` → dal.js:1608,1614).
- Efectos: `project._autosaveSuspendedByConflict = true` (no reintenta cada 1,5 s — respetado en `dalTouchProyecto`:1867 y en el flush :1879) y modal UNA sola vez (`_conflictoModalAbierto`). El modal (`_mostrarModalConflicto`, :1627-1652) distingue `seccion === 'cabecera'` vs filas de presupuesto (lista las filas por `clientUuid` vía `_budgetFindRow`).
- Salidas: "Recargar ahora" → `_conflictoRecargarAhora` (:1654-1666) → `dalReloadProyecto(id)` (:1297-1311, re-fusión con versiones frescas y línea base limpia) → reanuda autosave; "Recargar en un momento" → `_conflictoMasTarde` (:1668-1671) → banner persistente `#conflictoBanner` (:1673-1683) con el texto "Tus cambios no se están guardando hasta que recargues".
- Hermano no-conflicto: `manejarErrorPlan(err)` (plan-limites.js:81-100) parsea `TAKEOS_PLAN_LIMITE:<recurso>:<max>` y `TAKEOS_PLAN:<recurso>`; en `dalGuardarProyecto` un tope de proyectos revierte el proyecto optimista local si NUNCA se guardó (`!DAL_KNOWN_PROJECT_IDS.has(project.id)` → splice + volver al Control Room, :1559-1572).

### 3.5 Comportamiento offline

- No hay listeners `online/offline` ni `navigator.onLine` (`grep -rn "navigator.onLine\|'online'" frontend/src` → 0) ni cola de reintentos persistente.
- Sin `sb` (SDK no cargado): `cloudGate` no bloquea (`if (!client) { onUnlock(); return; }`, boot.js:370); los `dalBoot*` devuelven `null`/false y los stores mantienen su estado; los flags quedan `'pending'` → **toda escritura remota se salta** (guardas §3.1); la app funciona contra memoria + airbag localStorage.
- Con `sb` pero red caída a mitad de sesión: cada escritor captura el error, loguea y muestra toast "Sincronización parcial … Reintenta" (p. ej. dal.js:696, :720, :808, :852, :882, :912, :1887). El reintento es implícito: las marcas `_dirty/_headerDirty/_budgetPendingDeletes` no se limpian si el RPC falló, así que el próximo `markDirty→dalTouchProyecto→flush` reenvía. Para contactos/empresas/locaciones/legal NO hay marca pendiente: el reintento depende de volver a editar ("Reintenta al editar", :696).
- Al cerrar la pestaña con `STATE.dirty`: solo `autosaveNow()` (boot.js:681) — el guardado remoto pendiente dentro de la ventana de 1,5 s se pierde para la nube (queda en el airbag local, que hoy no se restaura — Hallazgo H1).

---

## 4. Multi-tenancy

### 4.1 `ORG_ID`

`export let ORG_ID = '640ab1e0-011c-43fe-a5aa-5a636005f56f';   // organización activa (default: Primate Films)` (state.js:40); setter `export function setOrgId(v) { ORG_ID = v; }` (state.js:231). Todas las lecturas del DAL filtran `.eq('organization_id', ORG_ID)` (p. ej. dal.js:198/201/317/373/377/423-429/1285) y todos los inserts lo estampan (`Object.assign({ id, organization_id: ORG_ID, ... })`, dal.js:680/709/798/842/872/907; payload core `{ id: project.id, organizationId: ORG_ID }`, :1461).

Resolución al arrancar (`resolverEspacioYArrancar`, boot.js:583-635): `memberships` activas del uid → 1 membresía interna sin invitaciones pendientes → `setTieneEmpresa(true); _bootCoverShow('Entrando a tu productora…'); _setOrgActiva(rows[0].organization_id); arrancarTakeOS();` (boot.js:626); multi-org o externos → Panel Personal (`renderEspacioUsuario`). El invariante V11.13.0 (boot.js:186-191): el Control Room jamás se muestra sin `_TIENE_EMPRESA` — ORG_ID **no** sirve de señal porque tiene default.

### 4.2 `_setOrgActiva` — paso a paso (boot.js:130-185)

```js
export function _setOrgActiva(orgId){
```
1. Normaliza y valida contra `const _ORG_UUID_RE = /^[0-9a-f]{8}-...-[0-9a-f]{12}$/i;` (:129); inválido → `return false` sin tocar la org actual (:133).
2. **Solo si `s !== ORG_ID`** (cambio real, :138) ejecuta el reset D0:
   a. **Rescate del guardado pendiente** (:139-147): `dalTouchProyecto(STATE.currentProject)` + `dalFlushProyectos()` — el flush arma el payload de forma SÍNCRONA (hasta el primer `await` en `sb.rpc`) con el `ORG_ID` saliente todavía vigente; "el RPC resuelve la org de filas existentes desde la BD, así que el write tardío no puede cruzarse" (:142-145).
   b. **Demolición de stores** (:148-153): `PROJECTS.length = 0; TRASH.length = 0;` + vaciado in-place de `BD_LOC/BD_LEGAL/BD_LEGAL_TPL` y de `BD_CONTACTOS/BD_EMPRESAS_BYID/BD_PERSONAS/BD_TALENTOS/BD_EMPRESAS` + `EMPRESA_PERFIL`.
   c. **Flags a pending** (:154-156): los 5 `setSource(..., 'pending')` — reabre la ventana de lectura y congela la escritura hasta confirmar lectura de la nueva org.
   d. `setTakeosAcceso(null);` (:157) — fail-closed hasta `dalLoadPermisos` de la nueva org.
   e. `STATE.currentProject = null` (:158).
   f. **Reset DAL**: `dalResetOrg()` (:159) — ver 4.3.
   g. **Reset persistencia local**: `window._persisResetOrg()` (:160) — pilas undo/redo + timer de autosave (persistencia-local.js:25-28).
   h. **Reset de VISTA** (:161-178): fuerza `STATE.currentView='control-room'; STATE.currentModule=null`, oculta `#projectView`, muestra `#controlRoomView`, vacía `#moduleMain/#bdGlobalMain/#sidebarProject`, resetea breadcrumb — mata la "vista fantasma" con nombres de la org anterior. Deliberadamente inline y NO `navigateToControlRoom()` (su guarda `!_TIENE_EMPRESA` redirigiría al Panel, :166-168).
3. `setOrgId(s)` (:181) y `localStorage.setItem(_ORG_LS_KEY, s)` (:182). `return true`.

Complemento en `dalBootProyectos`: si la `takeos_last_view` guardada es de OTRA org (`_lv.org !== ORG_ID`), navega al Control Room de la nueva (dal.js:1364-1369); la restauración de vista exige `_lv.org === ORG_ID` (:1346, :1358).

### 4.3 La ÉPOCA (`_ORG_EPOCA`)

- Lector: `function _dalEpoca() { return window._ORG_EPOCA || 0; }` (dal.js:1851).
- **Único punto de incremento**: `window._ORG_EPOCA = _dalEpoca() + 1;   // invalida toda cadena de boot en vuelo` dentro de `dalResetOrg()` (dal.js:1857), que además limpia los 6 sets `DAL_KNOWN_*` + `_dalDirtyProjects` y cancela `_dalSaveTimers` y `_dalProyFlushTimer` (:1858-1862). `_ORG_EPOCA` literal solo existe en dal.js:1851 y :1857 (`grep -rn "_ORG_EPOCA" frontend/src`).
- **TODOS los puntos de chequeo** (`grep -rn "_dalEpoca()" frontend/src` → 21 apariciones: 1 definición, 1 incremento, 9 capturas `const _ep = _dalEpoca()`, 10 comparaciones):
  | Función | Captura | Comparación(es) | Carrera que previene |
  |---|---|---|---|
  | `dalBootContactos` | :235 | :237 | Re-poblar `BD_CONTACTOS/BD_EMPRESAS_BYID` con datos de la org saliente tras el reset |
  | `dalBootPersonasExternos` | :257 | :262 | Inyectar contactos-lente ajenos |
  | `dalBootLocaciones` | :332 | :334 | Pisar `BD_LOC` con locaciones de otra org |
  | `dalBootLegal` | :392 | :394 | Ídem `BD_LEGAL/BD_LEGAL_TPL` |
  | `dalBootPerfil` | :457 | :459 | Ídem `EMPRESA_PERFIL` (marca/branding) |
  | `dalLoadPermisos` | :543 | :551 y :567 (tras cada await) | Aplicar `TAKEOS_PERFIL/TAKEOS_ACCESO` de una membresía de la org anterior |
  | `dalBootProyectos` | :1314 | :1316 | Fusionar proyectos de la org saliente sobre el tablero nuevo (y tocar el veil de la cadena vigente) |
  | `dalGuardarProyecto` | :1550 (`_epRPC`) | :1553 | Tras el RPC: "el write ya aterrizó en la org saliente; no re-contaminar `DAL_KNOWN_*` ni adoptar sobre un objeto muerto" |
  | `dalFlushProyectos` | :1873 | :1876 (dentro del for) | Seguir despachando guardados "con estado ajeno" a mitad de flush |
- Patrón invariante: *"Las cadenas de boot capturan la época al entrar y abortan tras cada await si cambió: una cadena obsoleta no puede re-poblar los stores recién reseteados con datos de la org anterior"* (dal.js:1853-1854, hallazgo de la auditoría adversarial de D0).

### 4.4 Rescate del guardado pendiente al cambiar de org

Secuencia exacta (boot.js:146-147 antes de la demolición :148): (1) `dalTouchProyecto(STATE.currentProject)` re-encola el proyecto abierto; (2) `dalFlushProyectos()` — su tramo síncrono (hasta `await dalGuardarProyecto(p)` → `sb.rpc`) construye `_dalProyectoPayload` con `organizationId: ORG_ID` **saliente** (aún no corre `setOrgId`, boot.js:181) y con `PROJECTS` aún poblado; (3) cuando el RPC resuelve, `_epRPC !== _dalEpoca()` (la época ya se incrementó en el paso f) → retorna sin adoptar respuesta ni contaminar `DAL_KNOWN_PROJECT_IDS` (dal.js:1553); (4) los ids restantes del set se abandonan en el chequeo del for (:1876). Ver Hallazgo H5 sobre el alcance real de este rescate.

---

## 5. Sesión, identidad y permisos

### 5.1 Login y sesión breve (`cloudGate`)

`export async function cloudGate(onUnlock)` (boot.js:368-550). Reglas:
- Retorno fresco de OAuth (`AUTH_RETORNO_OAUTH`, regex sobre hash+search, boot.js:77): poll de `getSession()` hasta 15×200 ms; al obtenerla estampa el **sello de autenticación explícita**: `takeos_auth_at` (Date.now) + `takeos_auth_uid` (boot.js:391-394) y limpia la URL.
- Sesión restaurada: se valida **contra el servidor** con `client.auth.getUser()` (boot.js:413, V11.15.0 — mata "sesiones fantasma" de usuarios borrados); entra sin login solo si `uid === takeos_auth_uid` **y** `Date.now() - takeos_auth_at < AUTH_TTL_HORAS*3600*1000` con `const AUTH_TTL_HORAS = 12;` (boot.js:84, chequeo :421-428). Si no: `signOut({ scope:'local' })` + limpieza de sellos + pantalla de login (Google OAuth con `prompt:'select_account'`, :492, o email+contraseña, :513-547).
- `window.logoutTakeOS` (boot.js:91-95): `signOut()` + borra `takeos_auth_at/auth_uid/usuario_actual/usuario_uid` + `location.reload()`.
- Arranque completo: `cloudGate(() => { iniciarSesionTakeOS(); })` (boot.js:686) → onboarding de perfil si falta fila en `user_profiles` (:654-660) → `resolverEspacioYArrancar()` → `arrancarTakeOS()` (boot.js:573-579) con la cadena: `dalBootTaxRates → dalBootContactos → dalResolveIdentidad → dalLoadPermisos → dalBootPersonasExternos → dalBootLocaciones → dalBootLegal → dalBootPerfil → dalBootProyectos → notifInit → _cpTourInicialQuizas → _pdCookiesBootCheck` (boot.js:578).

### 5.2 Identidad (`DAL_SESSION_UID/EMAIL`, `__TAKEOS_USER`, `USUARIO_ACTUAL`)

- Scalars sembrados en state.js:52-53: `window.DAL_SESSION_UID = null; window.DAL_SESSION_EMAIL = '';` — los escribe `dalResolveIdentidad()` (dal.js:482-483) por asignación global. `USUARIO_ACTUAL` (state.js:54) con setter `setUsuarioActual` (state.js:236); se cachea en `takeos_usuario_actual` desde `setCurrentUser` (boot.js:33).
- `dalResolveIdentidad()` (dal.js:476-515): sesión → uid/email; **anti nombre-ajeno** (V11.9.3 BUG-6): si `takeos_usuario_uid` cacheado ≠ uid actual, limpia `USUARIO_ACTUAL`, `window.__TAKEOS_USER` y la clave cacheada (dal.js:489-496); nombre real desde `user_profiles.nombre/apellido` por `user_id` (siempre legible: es su fila, dal.js:504-509), fallback por match de email en `BD_CONTACTOS` (:510-512); si hay nombre: `gancho('setCurrentUser')(nombreReal); window.__TAKEOS_USER = nombreReal;` + cachea `takeos_usuario_uid` (:513).
- `window.__TAKEOS_USER` es respaldo de lectura del topbar: `const nombre = ... USUARIO_ACTUAL ... : (window.__TAKEOS_USER || '');` (boot.js:255). También lo escribe `dalLoadPermisos` con el nombre del contacto vinculado a la membresía (dal.js:557-560).
- `function currentUser()` (boot.js:26-32): `USUARIO_ACTUAL` → `EMPRESA_PERFIL.remitenteNombre` → primera clave de `BD_PERSONAS` → `'Yo'`; expuesto como gancho `define('currentUser', currentUser)` (boot.js:734) y usado para asignación de tareas/señales.

### 5.3 Perfil y matriz de acceso (`TAKEOS_PERFIL` / `TAKEOS_ACCESO`)

- `export let TAKEOS_PERFIL = null; export let TAKEOS_ACCESO = null;` (state.js:44-45), setters :234-235.
- `dalLoadPermisos()` (dal.js:541-577): `memberships` por `(user_id, organization_id=ORG_ID)` con `permission_profiles(codigo,nombre)` embebido → `setTakeosPerfil({ codigo, nombre, tipo, profileId, contactId })` (:555); luego `profile_permissions (modulo, nivel)` por `profile_id` → `setTakeosAcceso({ modulo: nivel, ... })` (:568-570) → `gancho('renderTopbarUser')(); gancho('applyPermisosUI')();` (:571-572). Chequea la época tras cada await (:551, :567). Su `catch` es explícitamente fail-open: *"permisos no cargados (fail-open): … no se restringe nada"* (:573-576).
- Niveles: `'E'` (edición), `'L'` (lectura), `'none'`. Doctrina V11.15.0 (dal.js:526-533): **visibilidad/lectura fail-closed** — matriz sembrada densa, fila ausente = anomalía = negar; **guardas de escritura de cliente fail-open** cuando `TAKEOS_ACCESO === null`, porque la seguridad real la cierra el RPC SECURITY DEFINER (Gate C); la guarda de cliente es UX.

### 5.4 Helpers de decisión (lib/auth.js) y puntos de aplicación

Firmas reales (auth.js):
```js
export function authNivel(modCode) {            // :35 — null → 'none' (fail-closed)
export function authNivelModulo(appKey) {       // :45 — appKey sin mapear en MODULE_PERM_CODE → 'none'
export function authPuedeVer(appKey) { return authNivelModulo(appKey) !== 'none'; }   // :50
export function authEsAdmin() { return TAKEOS_PERFIL && (TAKEOS_PERFIL.codigo === 1 || TAKEOS_PERFIL.nombre === 'Administrador'); }   // :51
export function _puedeEditarResponsables() {    // :55 — sin perfil: true (fail-open); si no, codigo 1|2
export function _puedeEditarTareas() { return authNivel('tareas') === 'E'; }   // :61
export function authPuedeGuardarProyecto() {    // :65 — sin TAKEOS_ACCESO: true; si no, 'E' en presupuesto|cotizacion|info_proyecto|reporte_cierre
export function authPuedeGuardarOperaciones() { // :69 — sin TAKEOS_ACCESO: true; si no, authNivel('operacion_creatividad')==='E'
export function _authBlockWriteToast() {        // :74 — toast anti-spam (ventana 4000 ms)
```
Mapa appKey→código: `const MODULE_PERM_CODE = {...}` (auth.js:13-31), 17 módulos → 8 códigos (`info_proyecto, bd, presupuesto, cotizacion, operacion_creatividad, gastos_legal_notificaciones, tareas, reporte_cierre`).

Puntos de aplicación:
- **Sidebar/acciones globales**: `function applyPermisosUI()` (boot.js:275-301) — oculta `.sidebar-item[data-module]` sin `authPuedeVer`, agrega badge `'L'` de solo-lectura, y gobierna "Nuevo proyecto"/"Importar" por `authNivel('crear_proyecto') === 'E'` y el CFO por `authNivel('finanzas_consolidada') !== 'none'`.
- **Solo-lectura por módulo**: `function applyModuleReadonly(appKey)` (boot.js:312-325) — clase `mod-readonly` + banner "Solo lectura · tu perfil (…) puede ver este módulo pero no editarlo"; invocado en cada navegación (`gancho('applyModuleReadonly')(key)` en nav.js:245) y en cotización (presupuesto-cotizacion.js:2808).
- **Guardas de escritura RPC**: `if (!authPuedeGuardarProyecto()) { _authBlockWriteToast(); return false; }` (dal.js:1541) y `authPuedeGuardarOperaciones()` en 4a/4b/4c/4e (dal.js:1703/:1763/:1802/:1832).
- **Guardas puntuales**: `_puedeEditarResponsables` en lib/ui.js:474/:498 (dropdown de responsables de sección; el RPC 4b igual los ignora server-side para el resto, auth.js:52-54); `_puedeEditarTareas` en tareas.js:180/:228/:248/:250/:301; `newProject` bloquea con `authNivel('crear_proyecto') !== 'E'` (kanban.js:230); primer módulo visible con `_firstVisibleModule()` (boot.js:305-309) si `info-proyecto` está vetado (kanban.js:220-222).
- **Modo administrador** (capa aparte de la matriz): `export function _puedeModoAdmin() { if (!TAKEOS_PERFIL) return true; return authEsAdmin(); }` (admin.js:62-65); consumido en config.js:127/140/691/790, buscador.js:33, y en `importSaveFromInput` vía gancho (persistencia-local.js:191). "Cargar OS" exige además `STATE.adminMode` (persistencia-local.js:195).
- **Tope de colaboradores** (plan): cache `_TOPE_COLAB/_TOPE_COLAB_ORG` (state.js:66-67), poblado por `dalCargarTopeColaboradores` (dal.js:91-108), consumido por la UI de cargos con invalidación por org (`_TOPE_COLAB_ORG !== ORG_ID`, cargos.js:111-114/:199); la red de seguridad real es server-side en `guardar_cargos` (dal.js:89-90).

---

## Hallazgos

1. **[Deuda funcional] El "airbag" `takeos_autosave_v1` se escribe pero nunca se restaura como estado.** La única lectura de `LS_KEY` es `restoreLocalLocPhotos()` (persistencia-local.js:95), que solo reinyecta fotos de `bdLoc`. El comentario en persistencia-local.js:618-619 promete *"Al volver a abrir: si hay autoguardado válido, ofrecer restaurarlo"* y no hay código debajo. Desde que el boot es 100% Supabase, una edición que no alcanzó a sincronizarse (cierre dentro de la ventana de 1,5 s, o fallo de red) queda en el airbag pero se pierde de facto en la próxima carga: el flujo `beforeunload → autosaveNow()` (boot.js:681) protege contra un riesgo que ya no tiene consumidor.

2. **[Riesgo multi-org] Airbag y snapshots no están segregados por organización.** `LS_KEY='takeos_autosave_v1'` y `SNAP_KEY='takeos_snapshots'` son claves únicas sin `ORG_ID` (persistencia-local.js:44,253), pero `buildSaveObject()` serializa los stores de la org ACTIVA. Consecuencias: (a) el autosave de la org B pisa el de la org A en la misma clave; (b) `restoreSnapshot` → `applyLoadedState` (persistencia-local.js:301-303,116-147) no valida a qué org pertenece el snapshot: revertir un snapshot tomado en la org A estando activa la org B reintroduce en memoria proyectos/BD de A bajo `ORG_ID=B`, y `markDirty→dalTouchProyecto` podría empujarlos a la org equivocada (mitigado solo por RLS/validaciones del RPC). (c) `restoreLocalLocPhotos` matchea por `locId` (`'LOC-NN'`, formato colisionable entre orgs) sin filtro de org (persistencia-local.js:99-101).

3. **[Consistencia riesgosa] `_dalReplaceChildren` no es atómico.** El patrón delete-then-insert (dal.js:662-670) sobre `contact_roles/contact_bank_accounts/contact_companies/company_relationships` corre como 2 requests separados sin transacción: si el insert falla tras el delete (red, CHECK), los satélites del contacto quedan borrados en el servidor mientras el cliente los sigue mostrando; el toast dice "quedó en el respaldo local… Reintenta al editar" (dal.js:696) pero no hay marca pendiente que fuerce el reintento. Contrasta con `guardar_proyecto`, que es RPC atómico (dal.js:1379-1381).

4. **[Alcance limitado del rescate] El rescate de `_setOrgActiva` solo cubre en la práctica el primer proyecto sucio.** `dalFlushProyectos` compara la época dentro del `for` (dal.js:1876) y aborta tras el primer `await` (la época ya se incrementó en `dalResetOrg`); además la demolición (`PROJECTS.length = 0`, boot.js:148) hace fallar el `PROJECTS.find` de los ids restantes. Si dentro de la ventana de 1,5 s había MÁS de un proyecto en `_dalDirtyProjects` (posible con `dalTouchProyecto` desde acciones cross-proyecto del Control Room), esos otros se descartan en silencio. El comentario (boot.js:141-145) solo garantiza "el proyecto abierto".

5. **[Asimetría de concurrencia en undo] `_reconcileVersionsFromLive` solo protege cabecera y presupuesto.** El undo restaura el proyecto ENTERO (snapshot JSON) y las operaciones 4a/4b/4c/4e se guardan con contrato de "estado completo, la RPC reemplaza todo" (dal.js:1716-1717,1775-1777) **sin versionado**: tras un ⌘Z, el autosave reenvía tareas/señales/locaciones/documentos del snapshot viejo y pisa last-write-wins lo que otra sesión haya guardado en esas secciones, sin ningún `TAKEOS_CONFLICT` posible. Es coherente con el diseño actual, pero es una ventana de pérdida silenciosa multi-usuario que la Pasada 1 cerró solo para el núcleo.

6. **[Comentarios desactualizados / contradictorios]**
   - state.js:37-39 y :57-59 afirman que los scalars y los flags `*_SOURCE` "viven en window" y que dal.js "los escribe via window.X"; en realidad `setSource` (state.js:237-243) solo muta los bindings del módulo y `grep -rn "window\.\(CONTACTS\|LOCATIONS\|LEGAL\|PERFIL\|PROJECTS\)_SOURCE" frontend/src` devuelve 0. Ídem la cabecera de dal.js:6-8. También cargos.js:4 ("dal los escribe en window — lección #6") — hoy es `setTopeColab` importado.
   - dal.js:553 loguea `'[auth] sin membresía para el usuario (fail-open)'` cuando el efecto real de no setear `TAKEOS_ACCESO` es **fail-closed** para visibilidad (`authNivel(null)→'none'`) y fail-open solo para las guardas de escritura — el mensaje describe la mitad del comportamiento.
   - `TAKEOS_VERSION = 'V11.14.0'` (state.js:222) mientras el código referencia funcionalidades "V11.15.0" y "V11.16.0" ya integradas (boot.js:43,407; dal.js:248,1342,1559; auth.js:40) — versión visible sin bump.

7. **[Default caliente] `ORG_ID` nace con el UUID real de una org de producción** (`'640ab1e0-…'`, "Primate Films", state.js:40). El propio código lo reconoce como no-señal (boot.js:188-189) y `_TIENE_EMPRESA` + RLS mitigan, pero cualquier ruta futura que escriba antes de `_setOrgActiva` estamparía `organization_id` de Primate. `setOrgId` además no espeja a `window.ORG_ID` pese a la doctrina de setters de state.js:228-230 (no hay lectores `window.ORG_ID`, `grep` = 0, así que hoy es benigno).

8. **[Código muerto] `takeos_org_activa` es write-only.** Se escribe en cada `_setOrgActiva` (boot.js:182, "para futura entrada directa") y jamás se lee (`grep -rn "_ORG_LS_KEY\|takeos_org_activa"` → solo :128 y :182). La "entrada directa" a la última org sigue sin implementar; mientras tanto la clave acumula un UUID sensible-ish en localStorage sin consumidor.

9. **[UX de datos] Claves de configuración local no multi-tenant:** `takeos_notif_config_v1` (plantillas/remitente de correos con datos de la empresa, notificaciones.js:205) y `takeos_budget_colw` son globales por navegador: al cambiar de organización se arrastra la configuración de correos (razón social, RUT, banco por defecto de `notifEmpresaDefault`, notificaciones.js:223-227) de la org anterior hasta que el usuario la reescribe.

10. **[Realtime inexistente vs. producto multiusuario]** No hay canales realtime ni polling de `projects` (`grep .channel(` = 0): el conflicto solo se detecta AL GUARDAR (`TAKEOS_CONFLICT` en `guardar_proyecto`), y las secciones 4a-4e ni eso (Hallazgo 5). Dos sesiones sobre el mismo proyecto trabajan ciegas entre sí hasta el primer choque de versión del núcleo.