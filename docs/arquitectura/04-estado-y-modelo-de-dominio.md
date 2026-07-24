# Informe técnico — Modelo de estado y modelo de datos de dominio (Rizora)

Repositorio: `/home/juandlc/Trabajo/Take-OS` · rama `etapa4-integracion` · cliente `TAKEOS_VERSION = 'V11.14.0'` (`frontend/src/lib/state.js:222`). Todas las rutas son relativas a `frontend/src/` salvo indicación contraria. Todas las cifras fueron contadas con el comando indicado entre paréntesis.

---

## 1. `lib/state.js` (246 líneas) — inventario completo

Es el **dueño único del estado global compartido**. Contiene **29 `export let/const`** (`grep -c 'export let\|export const' lib/state.js` → 29) y **10 setters** (`grep -c 'export function set' lib/state.js` → 10). Lo importan **30 archivos** (`grep -rln "state.js'" --include='*.js' | wc -l` → 30, es decir, todo `lib/` salvo hojas puras + los 24 módulos + `main.js`).

### 1.1 Objetos compartidos por referencia (nunca reasignados)

| Export | Línea | Rol |
|---|---|---|
| `export const STATE = {...}` | `state.js:7-34` | Estado de UI/navegación. Se comparte por referencia; el contrato del encabezado (líneas 3-6) es explícito: *"Nunca se reasigna STATE entero (es const)"*. Espejo `window.STATE = STATE` en `state.js:226` y `main.js:48`. |
| `export const BD_CONTACTOS = {}` | `state.js:136` | Store **canónico** de personas físicas, id-keyed (`ctk_*`). |
| `export const BD_EMPRESAS_BYID = {}` | `state.js:137` | Store **canónico** de empresas, id-keyed (`emp_*`). |
| `export const BD_PERSONAS = {}` | `state.js:138` | **Proyección** legacy name-keyed (la consume la UI). |
| `export const BD_TALENTOS = {}` | `state.js:139` | Proyección legacy name-keyed de talentos. |
| `export const BD_EMPRESAS = {}` | `state.js:140` | Proyección legacy keyed por `nombreFantasia`. |
| `export const BD_LOC = []` | `state.js:149` | BD transversal de locaciones (canónica, sobrevive al cierre del proyecto). |
| `export const BD_LEGAL = []` | `state.js:151` | BD transversal de documentos legales. Sin espejo window (comentario `state.js:223`). |
| `export const BD_LEGAL_TPL = []` | `state.js:152` | Plantillas legales personalizadas (las oficiales viven en `LEGAL_TPL`, `modules/legal.js:42`, en código). |
| `export const PROJECTS = []` | `state.js:157` | Array de proyectos. |
| `export const TRASH = []` | `state.js:161` | Papelera: eliminar un proyecto lo mueve aquí, se conserva indefinidamente. |
| `export let EMPRESA_PERFIL = {...}` | `state.js:163-176` | Perfil de la productora emisora (multi-tenant V11: nace VACÍO, se carga de `organization_profile.profile`). ~30 campos planos: identidad fiscal, representante, banco, integraciones (`driveLink`, `chipaxLink`, …), remitente de correos. |
| `export const STATES_WITH_REAL_COST = ['preproduccion','produccion','postproduccion','cierre','cerrado']` | `state.js:92` | En estos estados el Presupuesto muestra columna "Costo Real". |
| `export const STATES_WITH_LOCKED_BUDGET = [...]` (misma lista) | `state.js:97` | Estados con presupuesto cotizado bloqueado (solo filas `extra` editables). |

### 1.2 Scalars mutables (`export let`) y su escritor

| Export | Línea | Escritor real (vía setter) |
|---|---|---|
| `ORG_ID` (default `'640ab1e0-…'` Primate Films) | `state.js:40` | `boot.js:181` (`_setOrgActiva`) |
| `USER_NOMBRE`, `USER_APELLIDO` | `state.js:42-43` | `boot.js:656` (perfil Supabase) |
| `TAKEOS_PERFIL`, `TAKEOS_ACCESO` | `state.js:44-45` | `dal.js:555`, `dal.js:570` / fail-closed en `boot.js:157` |
| `USUARIO_ACTUAL` | `state.js:54` | `boot.js:33-34` (localStorage), `dal.js:492` |
| `CONTACTS_SOURCE`, `LOCATIONS_SOURCE`, `LEGAL_SOURCE`, `PERFIL_SOURCE`, `PROJECTS_SOURCE` — todos `'pending'` | `state.js:60-64` | `setSource(...)` desde dal.js. Contrato fail-safe explícito (líneas 56-57): *"'pending' → 'supabase' tras la primera lectura exitosa (sin lectura confirmada NO se escribe)"*. Lectores contados por archivo (`grep -rn 'CONTACTS_SOURCE\|PROJECTS_SOURCE\|LOCATIONS_SOURCE\|LEGAL_SOURCE\|PERFIL_SOURCE' --include='*.js' | grep -v lib/state.js | grep -v setSource | awk -F: '{print $1}' | sort | uniq -c`): dal.js 25, gastos.js 5, info-proyecto.js 3, legal.js 3, notificaciones.js 3, cargos.js 2, locaciones.js 2, tareas.js 2, documentos.js 1, kanban.js 1. |
| `_TOPE_COLAB`, `_TOPE_COLAB_ORG` | `state.js:66-67` | `dal.js:101-102` (`dalCargarTopeColaboradores`); lectores: `cargos.js:111,114,199` y `dal.js:93,103`. |
| `_TIENE_EMPRESA` | `state.js:221` | `boot.js:626` y `espacio.js`/`invitaciones.js` (que se autodocumentan VETADOS para importarlo porque lo escriben: `espacio.js:6`, `invitaciones.js:4`). |

Excepción documentada: `window.DAL_SESSION_UID = null; window.DAL_SESSION_EMAIL = '';` (`state.js:52-53`) viven **en window, no como bindings** — deuda declarada de Etapa 2 (comentario líneas 47-51).

### 1.3 Setters — firmas reales (`state.js:231-246`)

```js
export function setOrgId(v) { ORG_ID = v; }
export function setUserNombre(v) { USER_NOMBRE = v; }
export function setUserApellido(v) { USER_APELLIDO = v; }
export function setTakeosPerfil(v) { TAKEOS_PERFIL = v; }
export function setTakeosAcceso(v) { TAKEOS_ACCESO = v; }
export function setUsuarioActual(v) { USUARIO_ACTUAL = v; }
export function setSource(cual, v) {
  if (cual === 'contacts') { CONTACTS_SOURCE = v; }
  else if (cual === 'locations') { LOCATIONS_SOURCE = v; }
  else if (cual === 'legal') { LEGAL_SOURCE = v; }
  else if (cual === 'perfil') { PERFIL_SOURCE = v; }
  else if (cual === 'projects') { PROJECTS_SOURCE = v; }
}
export function setTieneEmpresa(v) { _TIENE_EMPRESA = v; }
export function setTopeColab(v) { _TOPE_COLAB = v; }
export function setTopeColabOrg(v) { _TOPE_COLAB_ORG = v; }
```

Call-sites por archivo (`grep -rnE 'set(OrgId|UserNombre|UserApellido|TakeosPerfil|TakeosAcceso|UsuarioActual|Source|TieneEmpresa|TopeColab|TopeColabOrg)\(' --include='*.js' | grep -v lib/state.js | awk -F: '{print $1}' | sort | uniq -c`): `modules/dal.js` 11, `lib/boot.js` 9, `modules/espacio.js` 2, `modules/config.js` 1, `modules/invitaciones.js` 1, `modules/perfil-onboarding.js` 1.

### 1.4 Verificación del invariante "setters = única vía de escritura"

**Comando 1** (asignación léxica directa a cualquiera de los 15 scalars fuera de state.js, excluyendo arrows):

```
grep -rnE '(^|[^.a-zA-Z_])(ORG_ID|USER_NOMBRE|USER_APELLIDO|TAKEOS_PERFIL|TAKEOS_ACCESO|USUARIO_ACTUAL|CONTACTS_SOURCE|LOCATIONS_SOURCE|LEGAL_SOURCE|PERFIL_SOURCE|PROJECTS_SOURCE|_TOPE_COLAB|_TOPE_COLAB_ORG|_TIENE_EMPRESA|EMPRESA_PERFIL)\s*=[^=]' --include='*.js' | grep -v 'lib/state.js' | grep -v '=>'
```
→ **0 resultados**.

**Comando 2** (escrituras vía espejo `window.X =`, incluyendo las tasas de rates.js):

```
grep -rnE 'window\.(ORG_ID|USER_NOMBRE|...|EMPRESA_PERFIL|IVA|FACTOR_BOLETA|FACTOR_BTE|IMPUESTO_HONORARIOS|IMPUESTO_BTE|TAX_RATES_SOURCE)\s*=' --include='*.js'
```
→ **1 resultado**, y es el propio espejo de state.js: `lib/state.js:176: }; window.EMPRESA_PERFIL = EMPRESA_PERFIL;`.

**Comando 3** (lectores window residuales de los stores fuera de state.js/main.js): `grep -rn 'window\.\(BD_CONTACTOS\|BD_PERSONAS\|BD_EMPRESAS\|BD_TALENTOS\|BD_LOC\|PROJECTS\|TRASH\|EMPRESA_PERFIL\|STATE\)\b' --include='*.js' | grep -v lib/state.js | grep -v main.js | wc -l` → **0**.

**Veredicto: el invariante se cumple.** Matiz: `EMPRESA_PERFIL` es `export let` sin setter; su única escritura es mutación in-place (`Object.assign(EMPRESA_PERFIL, obj.empresaPerfil)`, `modules/persistencia-local.js:122`) — el invariante para él se sostiene por convención (nunca reasignar), no por API.

---

## 2. `lib/rates.js` (54 líneas) — tasas tributarias

Bindings mutables con defaults (red de seguridad), `rates.js:12-17`:

```js
export let IMPUESTO_HONORARIOS = 0.1525;      // concepto 'honorarios' (BHE)
export let IMPUESTO_BTE = 0.1525;             // concepto 'retencion_bte' (BTE); default = BHE hasta tener dato
export let IVA = 0.19;                        // concepto 'iva'
export let FACTOR_BOLETA = 1 - IMPUESTO_HONORARIOS;
export let FACTOR_BTE = 1 - IMPUESTO_BTE;
export let TAX_RATES_SOURCE = 'default';      // pasa a 'supabase' si se cargaron las tasas
```

**Escritor único**: `export async function dalBootTaxRates()` (`rates.js:24-54`). Contrato: lee `sb.from('tax_rates').select('concepto,tasa,vigente_desde,vigente_hasta')`, filtra vigencia por fecha (`desde <= hoy && (!hasta || hasta > hoy)`), resuelve concepto case-insensitive, normaliza `n > 1 → n/100`, y sobreescribe los bindings; en fallo devuelve `false` y la app sigue con defaults (*"Si Supabase no responde, la app sigue con estos defaults (nunca se rompe)"*, `state.js:196-200`). Se dispara como **primer eslabón** de la cadena DAL del boot: `dalBootTaxRates().then(...dalBootContactos...)` (`lib/boot.js:578`), y también se importa en `main.js:8` (puente `window.dalBootTaxRates`, `main.js:47`).

**Lectores** (`grep -rn "from '.*rates.js'" --include='*.js'`): `lib/data.js:12` (`FACTOR_BOLETA, FACTOR_BTE` → base de `factorRetencionDte`), `modules/calculadoras.js:19` (`IVA, FACTOR_BOLETA`), `modules/notificaciones.js:33` (`IVA`), `modules/config.js:26` (`IVA`), `modules/presupuesto-cotizacion.js:22` (`IVA`). El resto del código no lee tasas crudas: consume las funciones de `data.js` (regla en `data.js:42-48`: *"Todos los módulos … deben usar estas funciones — no recalcular aparte"*).

---

## 3. `lib/catalogos.js` (93 líneas) — hoja sin dependencias

Autodefinición (`catalogos.js:1-2`): *"hoja sin dependencias (la consumen modelo y data sin ciclo)"*. Contenido:

- `DEFAULT_DEPARTAMENTOS` (`:5-54`): 8 departamentos (Dirección, Producción, Dirección de Fotografía, Arte, Foto Fija, Locaciones, Catering, Postproducción) con filas semilla `{ rol, valor, unidad }`.
- `DEFAULT_EQUIPOS` (`:55-57`), `DEFAULT_GASTOS` (`:58-66`), `DEFAULT_TALENTOS` (`:67-70`): filas semilla `{ item, valor, unidad }`.
- `COTIZACION_CONDICIONES_DEFAULTS` (`:71-87`): 16 variables comerciales (validez, abono/saldo %, plazos, rondas, cancelación/reprogramación, `montosMasIVA: true`).
- `LOC_ESTADO_RANK = { confirmada: 3, candidata: 2, descartada: 1 }` (`:88`).
- `ROLES_OPERATIVOS = ['Crew', 'Interno', 'Contacto cliente', 'Proveedor individual']` (`:89`).

**Importadores directos** (`grep -rn "from '.*catalogos.js'"`): exactamente 2 — `lib/data.js:69` (que **re-exporta** todo en `data.js:70` para compat) y `lib/modelo.js:8`. Nadie más importa `DEFAULT_*` desde otro origen (`grep -rn "import {[^}]*DEFAULT_" | grep -v 'lib/data.js\|lib/modelo.js'` → 0). Los módulos consumen los demás catálogos vía `data.js` (11 importadores, ver §5).

---

## 4. Forma del estado

### 4.1 `STATE` — propiedades reales en runtime

Conteo de accesos (`grep -rnoE '(^|[^A-Za-z_$])STATE\.[a-zA-Z_$]+' --include='*.js' | grep -oE 'STATE\.[a-zA-Z_$]+' | sort | uniq -c | sort -rn`, ya depurado de `GO_STATE`):

| Propiedad | Accesos | Declarada en state.js | Notas |
|---|---|---|---|
| `currentProject` | 301 | sí (`:9`) | Referencia al objeto proyecto abierto (no un id). `null` en Control Room. |
| `ui` | 47 | sí (`:23-33`) | Sub-shape declarado: `collapsed{}` (key `projectId+':'+dept`), `budgetSort{}` (solo presentación, NO persiste), `bdSearch`, `bdExpanded`, `hojaDiaSel`, `prDiaSel`, `prUnidadId`, `prVarId`, `prSelFila`. En runtime se agregan `ui.bdTab` (`modules/bd.js:1132`), `ui.ntf` (`modules/notificaciones.js:388`), `ui.budgetCollapseCotizado` (`modules/presupuesto-cotizacion.js:92`). |
| `currentModule` | 29 | sí (`:10`) | default `'info-proyecto'`. |
| `adminMode` | 29 | sí (`:19`) | Escrito en `modules/admin.js:73,78`, `modules/buscador.js:33`, `modules/config.js:712`. |
| `prDiaSel` / `prSelFila` / `prVarId` / `prUnidadId` | 24/17/13/10 | **no como top-level** | Plan de Rodaje los usa **a nivel raíz de STATE** (p.ej. `modules/plan-rodaje.js:239-241`), pero state.js los declara **dentro de `ui`** (`:29-32`). Ver Hallazgo H2. |
| `currentView` | 17 | sí (`:8`) | `'control-room' | 'project'`. |
| `dirty` | 7 | **no** | Creada ad hoc por `markDirty()` (`modules/persistencia-local.js:507`); leída en `lib/boot.js:679,681`. |
| `loc` | 6 | **no** | Sub-estado del módulo Locaciones, lazy: `if (!STATE.loc) STATE.loc = { sub: 'repo', filtro: 'todas' }` (`modules/locaciones.js:74`). |
| `legal` | 3 | **no** | Lazy: `{ sub:'docs', filtroTipo:'', filtroEstado:'', q:'', fDesde:'', fHasta:'', gen:null }` (`modules/legal.js:129`). |
| `currentViewMode` / `currentFilter` | 1/1 | sí (`:11-12`) | **Solo se escriben** (`lib/ui.js:703,712`); ningún lector (grep completo → solo declaración + escritura). Ver Hallazgo H8. |

### 4.2 `PROJECTS` — estructura de un proyecto

**Campos de primer nivel** (constructor en `modules/kanban.js:261-266`, idéntico en `modules/dal.js:1324` e `modules/info-proyecto.js:476`):

```js
PROJECTS.push({
  id, client: cliente, name: nombre, state: 'venta',
  pe: pe || '—', amount: 0, currency: 'CLP',
  alerts: 0, lastActivity: 'Recién creado', date: '—',
  data: buildProjectData({ infoProyecto: { cliente, nombreProyecto: nombre, productorEjecutivo: pe, fechaCotizacion: ... } })
});
```

`id` local = `'P-' + Date.now()` (`kanban.js:260`); en nube es el uuid de `projects.id`. Tras hidratar desde Supabase, `_dalFusionarProyecto` agrega **campos runtime de concurrencia** (`dal.js:1244-1248`): `_headerVersion` (espejo de `projects.version`), `_headerDirty`, `_headerDirtySeq`, `_budgetPendingDeletes[]`, `_snap` (línea base snapshot-diff de secciones no migradas).

**`project.data`** — campos de primer nivel según la fábrica `buildDefaultProjectData()` (`lib/modelo.js:245-382`): `infoProyecto`, `finanzas`, `servicios{}`, `gastos[]`, `equipos[]`, `talentos[]`, `crewExtra{}`, `responsables{}`, `tareas[]`, `senales[]`, `asistentes{cliente,agencia,externo}`, `crewExternos[]`, `cotizacion`, `rodajes[]`, `locaciones[]`, `hojaLlamado`. A esto se suman claves creadas **lazy** por módulos: `planRodaje` (`modules/plan-rodaje.js:92`), `gastosOp` (`modules/gastos.js:84`), `cotizaciones` (`modules/presupuesto-cotizacion.js:2445`), `documentos` (`dal.js:1242` / `modules/documentos.js:80`), `gastoComments` (`dal.js:1234`), `_locMigrated` (`modelo.js:456,466`).

### 4.3 Stores BD_* e índices

- **Canónico**: `BD_CONTACTOS[id]` + `BD_EMPRESAS_BYID[id]`; **proyecciones derivadas solo-lectura**: `BD_PERSONAS[nombre]`, `BD_TALENTOS[nombre]`, `BD_EMPRESAS[nombreFantasia]`, reconstruidas con `syncLegacyFromContactos()` tras cualquier cambio (contrato en `state.js:112-120`). Las vistas legacy llevan `_id` de vuelta al canónico (`modelo.js:160,177,197`).
- IDs generados por `export function _genId(prefix, store)` (`modelo.js:476-481`): `prefix + '_' + rand36(6) + Date.now()36.slice(-4)`, con reintento anti-colisión contra el store.
- `BD_LOC` es **array** (no dict) de `{ locId:'LOC-NN', nombre, direccion, direccion2, comuna, ciudad, region, maps, orientacion, contactos:[{nombre,mail,tel,obs,relacion}], notas, fotos:[{url}] }` (esquema en `state.js:145-148`; constructor real `modules/locaciones.js:552`).
- `BD_LEGAL` es array de registros `docId`-keyed lógicamente (shape en §6.5); `BD_LEGAL_TPL` array `{ id, nombre, desc, target, completar, cuerpo, custom:true }` (`modules/legal.js:444`).

### 4.4 `TRASH`

Escritores (`grep -rn 'TRASH' --include='*.js' | grep -v lib/state.js`): `modules/kanban.js:334` (`TRASH.unshift(proj)` al eliminar), `modules/info-proyecto.js:481` (ensambla en TRASH los borrados de nube, dedupe por id en `:474`), restauración `info-proyecto.js:515-537` (`TRASH.splice(i,1)` + `PROJECTS.push(proj)`), vaciado por cambio de org `boot.js:148` (`PROJECTS.length = 0; TRASH.length = 0;`), y persistencia (`persistencia-local.js:65,121`). En nube la papelera es `projects.deleted_at` (`dal.js:1286`: `soloBorrados ? q.not('deleted_at','is',null) : q.is('deleted_at',null)`).

---

## 5. `lib/modelo.js` (531 líneas) vs `lib/data.js` (70 líneas)

**Reparto de roles**: `data.js` = **constantes/catálogos + lógica tributaria pura** (funciones sin estado); `modelo.js` = **fábricas de entidades, normalizadores y migradores** que **mutan los stores** de state.js. `modelo.js` DEBE importarse antes que `data.js` (advertencia `modelo.js:2-3`); `data.js` importa `buildDefaultProjectData` de modelo (`data.js:10`) y tasas de rates (`data.js:12`).

### 5.1 `lib/data.js` — funciones y constantes

Constantes: `LOC_ORIENTACIONES` (`:13`), `LOC_ESTADOS` (`:14`), `REGIONES_CHILE` (`:17`, 16 regiones norte→sur), `BANCOS_CHILE` (`:19-30`, 20 bancos con código SBIF), `DTE_OPTIONS` (`:32-37`, valores `boleta|factura|factura_exenta|boleta_terceros`), `DTE_LABEL`/`DTE_LABEL_SHORT` (`:38-39`), `DTE_CON_RETENCION = ['boleta','boleta_terceros']` (`:40`), `UNIDAD_OPTIONS = ['Tarifa Plana','Jornadas','Horas','Personas','Locaciones','Fotografías']` (`:60`). Lógica tributaria central (contrato `data.js:42-48`):

```js
export function dteTieneRetencion(dte) { return DTE_CON_RETENCION.indexOf(dte) !== -1; }
export function factorRetencionDte(dte) {
  if (dte === 'boleta_terceros') return FACTOR_BTE;
  if (dteTieneRetencion(dte)) return FACTOR_BOLETA;
  return 1;
}
export function montoNetoDesde(costoReal, dte) { ... }
export function montoBrutoDesde(liquido, dte) { ... }
```

Importadores (`grep -rn "from '.*data.js'"`): `lib/ui.js`, `lib/calc.js`, y los módulos `bd`, `perfil-onboarding`, `notificaciones`, `legal`, `dal`, `locaciones`, `calculadoras`, `gastos`, `presupuesto-cotizacion` (11 archivos).

### 5.2 `lib/modelo.js` — funciones principales

- **Fábricas de proyecto**: `export function buildDefaultProjectData()` (`:245-382`) — estructura completa (§4.2); `export function buildProjectData(overrides)` (`:385-421`) — aplica overrides por sección (usada por demo/creación); `export function _clientUuid()` (`:237-243`) — UUID v4 con fallback sin `crypto.randomUUID`.
- **Modelo de contactos**: `export function _buildPerfilPago(o)` (`:22-30`), `export function _buildPerfilTalento(o)` (`:31-36`), `function normalizeContacto(c)` (`:39-49`, asegura `id`, `roles` no vacío default `['Crew']`, strings normalizados, perfiles objeto-o-null).
- **Migrador legacy→canónico**: `export function ingestLegacyIntoContactos()` (`:56-148`) — reconstruye `BD_CONTACTOS`/`BD_EMPRESAS_BYID` desde las proyecciones de un save V7.2 o un .xlsx de 3 hojas; dedup por `rut > email > nombre` (`_dedupKeys`, `:484-490`); merge Talento→contacto existente; resolución de `contactoPrincipalId`.
- **Sync canónico→legacy**: `export function syncLegacyFromContactos()` (`:184-203`) — regenera las 3 proyecciones. Regla de proyección (`:189-192`): a `BD_PERSONAS` va todo contacto operativo **o** no-talento-puro; a `BD_TALENTOS` todo el que tenga rol `'Talento'`.
- **Hidratador de save**: `export function hydrateContactStore(obj)` (`:206-225`) — chokepoint: si el save trae `bdContactos` normaliza y sincroniza; si es formato viejo, `ingestLegacy…` + `sync…`.
- **Locaciones por proyecto**: `export function ensureProjectLoc(project)` (`:469`) → `migrateProjectLocaciones` (`:450-468`, migra `hojaLlamado.locaciones` legado V8.1 a `BD_LOC` + `PROJ_LOC`, marca `d._locMigrated`) + `dedupeProjectLocaciones` (`:429-448`, dedupe por `locId` y por nombre normalizado con `normLocName`, conservando el estado de mayor `LOC_ESTADO_RANK`).
- Helpers de store: `export function _genId(prefix, store)` (`:476`), `export function _clearStore(s)` (`:482`).

---

## 6. Entidades de dominio y relaciones

Grafo: **Proyecto** →(1:1) `data.servicios/gastos/equipos/talentos` (presupuesto) →(1:1) `data.cotizacion` + `data.cotizaciones.versiones[]` (ofertas y versiones) →(1:N) `data.rodajes[]` (días, `diaId` estable) →(por `diaId`) `data.planRodaje.dias{}` y `data.hojaLlamado.dias{}` →(1:1) `data.gastosOp` (movimientos). Transversales: `BD_CONTACTOS` (referenciado por **nombre** en filas de presupuesto y por `contact_id` en nube), `BD_LOC` (referenciado por `locId` desde `data.locaciones[]` y legal), `BD_LEGAL` (referencia `proyectoId` + `contraparteId` persona-o-locación; *"El tab Legal de un proyecto es una vista filtrada de BD_LEGAL"*, `modelo.js:475`).

### 6.1 Fila de presupuesto (la estructura más caliente del sistema)

Semilla local (`modelo.js:376-379` servicios; `:305-307` gastos/equipos/talentos):

```js
// servicios:  { nombre:'', rol, valor, unidad, dte:null, cantidad:0, confirmado:false, costoReal:null }
// gastos/equipos/talentos: { nombre:'', item, valor, cantidad:0, unidad, dte:null, confirmado:false,
//                            costoReal:null, clientUuid:_clientUuid(), version:null, _dirty:true, _dirtySeq:1 }
```

Shape completo tras hidratación de nube (`function _dalBudgetRow(r, esServicio)`, `dal.js:938-957`): agrega `dteReal:null` (gap declarado: sin columna en esquema Tanda 3), `extra` (`es_extra`), `prontoPago` (`es_pp`), `horaExtra`, `heConfig` (jsonb de inputs HE; `hora_extra` es cache del costo), `clientUuid`/`version` (concurrencia por fila) y `_contactId`. La sección BD `'tecnica'` equivale a `'equipos'` en cliente (`dal.js:1187`).

**Contrato de cálculo** (`lib/calc.js`): `export function calcCostoEmpresa(valor, cantidad, dte, sectionKey)` retorna `{ value: number|null, error: string|null }`; DTE opcional en `gastos|equipos` (asume factura), requerido en servicios/talentos (`error:'FALTA DTE'`); retención: `Math.round((valor / factorRetencionDte(dte)) * cantidad)`; redondeo a peso entero en la fuente (V9.6.13). `export function getCostoReal(item, sectionKey)`: el real es **literal**, el DTE no multiplica. `export function calcProjectTotals(project)` → `{ totalCot, totalReal, hasReal, alerts }`; primero ejecuta `gancho('_syncGastosCostoReal')(project)` (el Real de Gastos se deriva de movimientos, no de tipeo — "REGLA MADRE" en `gastos.js:43-46`: *"el gasto solo escribe el Real (rollup). El Cotizado se LEE del Presupuesto vía calcSummaryFin… jamás se escribe desde aquí"*), y suma `horaExtra` como costo real adicional.

### 6.2 Cotización: ofertas + versiones

`data.cotizacion = { fechaEmision, representanteCliente, condiciones: {…16 campos…}, ofertas: [] }` (`modelo.js:333-338`). Oferta (`presupuesto-cotizacion.js:2723-2737`):

```js
{ id:'of_…', esBase, nombre, valorCliente, descripcion,
  incluye:[], noIncluye:[],           // noIncluye SIEMPRE manual (decisión comercial, V6.1 Nota 5c)
  entregables:{ videos:[{nombre,variables[]}], fotografia:[], otros:[] },
  presupuestoAlt: null | snapshotFromBudget(project) }   // copia liviana sin nombres/datos operativos
```

Versionado V7.5 (`function ensureCotizaciones(project)`, `:2440-2459`): `d.cotizaciones = { activoId, versiones: [{ id:'cv_…', numero, label, nota, createdAt, resumen, …campos de cotizacion }] }`; **invariante de compat**: `d.cotizacion = cs.versiones.find(v => v.id === cs.activoId)` (espejo de la activa, `:2458`); la oferta base sigue al Presupuesto en vivo **solo** en la última versión; las anteriores congelan `resumen` (historial de negociación).

### 6.3 Rodajes y Plan de Rodaje

Rodaje (`modules/rodajes.js:156-161`): `{ fecha:'', activo:true, descripcion:'', diaId: nextDiaId(rodajes) }` — `diaId` con formato `DIA-NN`, **nunca se elimina un día: se desactiva** (PRD §5.6); borrar un día borra en cascada su hoja (`rodajes.js:202`).

Plan de Rodaje (`plan-rodaje.js:90-137`), modelo **Día → unidades[] → variantes[]**:

```js
d.planRodaje = { columnas: { termino, escPlano, extra:[{id,label,tipo,on}] }, dias: {}, orientacion:'horizontal' }
pr.dias[diaId] = { header:{locacion, solUtilAmanecer, solUtilAtardecer, responsable, responsableContacto},
                   unidades:[{ id:'uni_…', label, variantes:[{ id:'var_…', label, filas:[], banco:[], version, lastExport }], activoVarId }],
                   activoUnidadId }
```

Con migradores in situ V7.7→V7.8 (`dd.planes`) y V7.6→V7.8 (`dd.variantes`) en `prEnsureDia` (`:113-127`), y `function prMigrateFila(f)` (`:139-147`) que backfillea `{ id, tipo:'plano', dur, anchor, paralelo, escPlano, accion }`.

### 6.4 Hoja de Llamado

`data.hojaLlamado = { version:1, locaciones:[] /*LEGADO V8.1-*/, dias:{} }` (`modelo.js:369-373`). Día (`function ensureHojaDia(diaId)`, `plan-rodaje.js:556-576`):

```js
hl.dias[diaId] = {
  infoGeneral: { llamadoGeneral, almuerzo, amanecer, atardecer, wrapCamara, wrapLocacion, hospital, clima },
  citacionesExternas: [],
  crewOverrides: {},   // nombre → { call, locacionId, notas, presente, rol, numero }
  crewOrden: [],       // orden manual por día (V11.25)
  version: 0,          // 0 = borrador; +1 por export
  lastExport: null     // { version, at } | null
}
```

El crew base se **deriva** del Presupuesto: filas con `r.confirmado && r.nombre && !r.noVaRodaje` de servicios + gastos/equipos/talentos (`plan-rodaje.js:542-548`); la Hoja no es fuente de verdad (PRD §06). Versionado y export son **por día** (cada día es un PDF).

### 6.5 Gastos operativos, Legal y locación de proyecto

`data.gastosOp` (`gastos.js:81-93`): `{ cajaProd:0, cajaDevuelto:0, cajaMovs:[], presupuestos:[{id,nombre,linea,resp,asignado}], movimientos:[], lineasExtra:[String] }`. Movimiento real (`gastos.js:750-757` + `:785`): `{ id:'m…', pres, fecha, quien, registra, concepto, prov, monto, medio, tipo, comp, estado:'pendiente'|'por_revisar'|…, coment, fileName, filePath, fileUrl, fechaPago:null, objetivo:null, datosPago:{rut,email,banco,tipoCuenta,nCuenta}|null }`; estados en `GO_ESTADOS` (`gastos.js:72`).

Documento legal (`modules/legal.js:749-771`): `{ docId, tipo, plantillaId, proyectoId, proyectoNombre, cliente, estado:'generado'→'enviado'→'firmado', version, fechaGeneracion, fechaFirma, monto, vigencia, responsable, pdfUrl, vars, contraparteId, contraparteNombre, rut, rolCalidad, locacionId? , historial:[{version,at,vars}] }` — re-generar un doc empuja la versión anterior a `historial` (`:737-741`).

Uso por-proyecto de locación (`locaciones.js:552-553`, esquema en `modelo.js:367`): `{ locId, estado:'candidata'|'confirmada'|'descartada', costo, contratacion, notasProy }` — el registro físico vive en `BD_LOC`.

### 6.6 Persistencia y espejo relacional

Save local (`function buildSaveObject()`, `persistencia-local.js:58-81`, `SAVE_FORMAT_VERSION = 5`): `{ app:'TakeOS', format:'takeos-save', version, savedAt, projects, trash, empresaPerfil, bdContactos, bdEmpresasById, bdLoc, bdLegal, bdLegalTpl, bdPersonas, bdEmpresas, bdTalentos }` — las proyecciones legacy se siguen escribiendo por compat V7.2.x. Las fotos de BD_LOC **no viajan por nube** (tope 1 MiB; se reinyectan de localStorage vía `restoreLocalLocPhotos()`, `:93-103`).

En Supabase el proyecto se descompone en ~20 tablas relacionales — ver `_dalProyectoSelect()` (`dal.js:1254-1279`): `projects` (+`version` de cabecera), `project_commercial`, `project_assignments`, `project_financials`, `project_commissions/risks/income_extras`, `budget_line_items` (+`client_uuid,version` por fila), `project_quotation`, `quotation_offers`, `quotation_versions`, `project_shoot_days`, `project_shooting_plan(plan)` y `project_call_sheet(data)` (jsonb blob), `project_locations`, `project_crew_extra`, `project_external_crew`, `project_section_responsibles`, `project_operations`, `project_op_budgets`, `project_tasks(+task_comments,task_attachments)`, `project_signals`, `project_documents`, `gasto_comments`. La fusión nube→memoria es `export function _dalFusionarProyecto(target, partes)` (`dal.js:1205-1250`).

---

## Hallazgos

- **H1 · TDZ latente en `state.js:54`**: `export let USUARIO_ACTUAL = ('USUARIO_ACTUAL' in window) ? USUARIO_ACTUAL : '';` — el `USUARIO_ACTUAL` del lado derecho resuelve al **propio binding de módulo en TDZ** (modo estricto), no a `window.USUARIO_ACTUAL`. Si algún día existiera `window.USUARIO_ACTUAL` antes de evaluar state.js, la app lanzaría `ReferenceError` en el arranque. Hoy la rama es muerta (`grep -rn 'window.USUARIO_ACTUAL' --include='*.js'` → 0), pero el código es una trampa.
- **H2 · Defaults muertos en `STATE.ui`**: `prDiaSel/prUnidadId/prVarId/prSelFila` están declarados **dentro de `ui`** (`state.js:29-32`), pero todo Plan de Rodaje los usa como **top-level** (`STATE.prDiaSel` 24 usos, `STATE.ui.prDiaSel` 0 usos; comando de §4.1 + `grep -rn 'ui\.prDiaSel'` → 0). Los defaults declarados jamás se leen; la forma documentada del estado difiere de la real.
- **H3 · Shape de STATE no cerrado**: propiedades creadas ad hoc fuera de la declaración: `STATE.dirty` (`persistencia-local.js:507`), `STATE.loc` (`locaciones.js:74`), `STATE.legal` (`legal.js:129`), más los `pr*` de H2 y los `ui.bdTab/ui.ntf/ui.budgetCollapseCotizado`. No rompe el invariante de setters (STATE se muta por diseño), pero no hay un único lugar donde leer el shape completo.
- **H4 · Restos muertos en `rates.js`**: `function _espejo() { }` está vacía y se invoca dos veces (`rates.js:18-22` y `:48`) — residuo del apagado de espejos window.
- **H5 · `TAX_RATES_SOURCE` es un flag huérfano**: se escribe (`rates.js:47`) pero no tiene ningún lector fuera de rates.js (`grep -rn 'TAX_RATES_SOURCE' --include='*.js' | grep -v rates.js` → 0), a diferencia de los `*_SOURCE` de state.js que sí gobiernan el fail-safe de escritura.
- **H6 · Excepción window residual**: `window.DAL_SESSION_UID` / `window.DAL_SESSION_EMAIL` (`state.js:52-53`) siguen en window y no como bindings con setter; deuda auto-documentada ("se extraeran limpio en Etapa 2") aún abierta en Etapa 4.
- **H7 · Deriva de comentarios**: (a) el esquema de contacto en `state.js:130` lista `cumpleanos`, pero el código usa `fechaNacimiento` (`modelo.js:44,101`); (b) cabeceras de `data.js:2-7` y `modelo.js:2-3` siguen describiendo `DEMO_PROJECTS` y su orden de evaluación, pero DEMO_PROJECTS fue eliminado en D0 (`main.js:11`); (c) `catalogos.js:2-3` promete "bridges window viajan con ellos" y el bloque de espejos está vacío (`catalogos.js:91-93`); (d) `cargos.js:4` dice que dal escribe `_TOPE_COLAB` "en window" cuando hoy usa `setTopeColab` (`dal.js:101`); (e) `gastos.js:91-92` marca `cajaDevuelto/cajaMovs` como "no persiste aún" pero `_dalProyectoSelect` ya selecciona `caja_devuelto, caja_movimientos` de `project_operations` (`dal.js:1273`).
- **H8 · Estado write-only**: `STATE.currentFilter` y `STATE.currentViewMode` solo se escriben (`lib/ui.js:703,712`) y nadie los lee (grep completo → 0 lectores) — candidatos a retiro.
- **H9 · Espejos window sin lectores**: `state.js` mantiene bridges (`window.STATE`, `window.PROJECTS`, `window.TRASH`, `window.BD_*`, `window.EMPRESA_PERFIL`, `window.STATES_WITH_*`) pese a que fuera de state.js/main.js hay **0 lectores** de esas propiedades vía window (comando 3 de §1.4). Coherente con la purga D4c a medio retirar (commit `e2e9c5a`: "27/27 props sin lector").
- **H10 · `dteReal` gap declarado**: `_dalBudgetRow` inicializa `dteReal: null` con el comentario "el esquema Tanda 3 no tiene columna de DTE real" (`dal.js:947`) — el DTE del costo real se pierde en el round-trip con Supabase.