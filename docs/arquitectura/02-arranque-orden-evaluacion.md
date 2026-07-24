# Ciclo de vida de arranque y orden de evaluación — Rizora (`frontend/src/`)

Base analizada: rama `etapa4-integracion`, HEAD `4c8067b`. Cifras contadas sobre el árbol de trabajo. 40 archivos `.js` bajo `frontend/src/` (`find frontend/src -name '*.js' | wc -l` → 40: `main.js` + 14 en `lib/` + 25 en `modules/`). 365 sentencias `import` estáticas en total (`grep -hE "^import " main.js lib/*.js modules/*.js | wc -l`), 0 `import()` dinámicos (`grep -rn "import(" lib modules main.js` → vacío).

---

## 1. `frontend/src/main.js` (50 líneas)

### 1.1 Manifiesto de imports en orden textual (36 entradas; `grep -c "^import" src/main.js` → 36)

| # | Línea | Import | Comentario de orden en el propio archivo |
|---|---|---|---|
| 1 | 6 | `import { escapeHtml, safeUrl, showToast } from './lib/helpers.js';` | — |
| 2 | 7 | `import { supabaseInit } from './lib/supabase.js';` | — |
| 3 | 8 | `import { dalBootTaxRates } from './lib/rates.js';` | — |
| 4 | 9 | `import { STATE } from './lib/state.js';` | — |
| 5 | 10 | `import './lib/modelo.js';` | "C5: modelo contactos + fábrica de proyectos" |
| 6 | 11 | `import './lib/data.js';` | "catálogos y presets en window (…) — DEMO_PROJECTS eliminado en D0" |
| 7 | 12 | `import './lib/auth.js';` | — |
| 8 | 13 | `import './lib/calc.js';` | — |
| 9 | 14 | `import './lib/ui.js';` | — |
| 10 | 15 | `import './lib/nav.js';` | **"C5 ⚠ antes de gastos.js: goWire lee window.MODULES en eval"** |
| 11 | 16 | `import './modules/kanban.js';` | "puentea STATES, renderKanban, navigateToControlRoom, etc." |
| 12–35 | 17–40 | `notificaciones`, `presupuesto-cotizacion`, `locaciones`, `legal`, `plan-rodaje`, `bd`, `bd-excel`, `buscador`, `config`, `dal`, `gastos`, `persistencia-local`, `perfil-onboarding`, `documentos`, `rodajes`, `info-proyecto`, `crew`, `tareas`, `cargos`, `invitaciones`, `admin`, `plan-limites`, `espacio`, `calculadoras` | comentarios "puentea X, Y, Z" por línea (inventario de símbolos históricos) |
| 36 | 41 | `import './lib/boot.js';` | **"C6/D1: última entrada del manifiesto; su EVAL real se adelanta por imports (hoy ~29 vía perfil-onboarding) — su top-level solo requiere state + DOM estático (auditado)"** |

Los únicos dos comentarios que declaran **contratos de orden** son main.js:15 y main.js:41. Ambos están hoy desactualizados (ver Hallazgos H3/H4).

### 1.2 Después de los imports (main.js:43-50)

Seis puentes a `window` y un log:

```js
window.escapeHtml = escapeHtml;
window.safeUrl = safeUrl;
window.showToast = showToast;
window.supabaseInit = supabaseInit; // al llamarse, setea window.sb
window.dalBootTaxRates = dalBootTaxRates;
window.STATE = STATE; // mismo objeto compartido (estado global)
```
y `console.info('[desacople] arranque modular OK · ganchos, imports y CSP estricta activos');` (main.js:50).

**Contexto de carga**: `frontend/index.html:1287` — `<script type="module" src="/src/main.js"></script>`, precedido por dos scripts clásicos CDN: `xlsx.full.min.js` (index.html:1282) y `@supabase/supabase-js@2` (index.html:1284, expone el global `supabase` que consume `supabaseInit`, supabase.js:20). CSP en index.html:35: `script-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com` — sin `unsafe-inline`. Al ser `type=module` (deferred), **todo el grafo evalúa con el DOM ya parseado pero antes de `DOMContentLoaded`**: el acceso eval-time a nodos estáticos (p.ej. `#bootVeil`, index.html:1279) es válido por construcción.

---

## 2. Orden EFECTIVO de evaluación ≠ orden del manifiesto

Método: DFS postorden sobre los `import` estáticos partiendo de `main.js` (semántica ESM: un módulo evalúa cuando su primer importador lo alcanza, tras evaluar recursivamente sus dependencias en orden textual). Script Python read-only con resolución de especificadores relativos y comentarios excluidos; ejecutado sobre el árbol. Resultado: 39 aristas de árbol (las que disparan evaluación) y **49 aristas de retroceso** (imports hacia módulos aún a mitad de evaluación, es decir, ciclos).

### 2.1 Secuencia efectiva de evaluación (40 posiciones)

| eval # | módulo | pos. manifiesto | evaluación disparada por |
|---|---|---|---|
| 1 | lib/helpers.js | 1 | main.js |
| 2 | lib/supabase.js | 2 | main.js |
| 3 | lib/rates.js | 3 | main.js |
| 4 | lib/state.js | 4 | main.js |
| 5 | lib/catalogos.js | — | lib/modelo.js:8 |
| 6 | lib/ganchos.js | — | lib/modelo.js:9 |
| 7 | lib/modelo.js | 5 | main.js |
| 8 | lib/data.js | 6 | main.js |
| 9 | lib/auth.js | 7 | main.js |
| 10 | lib/calc.js | 8 | main.js |
| 11 | lib/delegacion.js | — | lib/ui.js:10 |
| 12 | lib/ui.js | 9 | main.js |
| 13 | lib/nav.js | 10 | main.js |
| 14 | modules/plan-limites.js | **33** | modules/dal.js:26 |
| 15 | modules/bd-excel.js | 18 | modules/bd.js:19 |
| 16 | modules/notificaciones.js | 12 | modules/gastos.js:19 |
| 17 | modules/gastos.js | **22** | modules/bd.js:21 |
| 18 | modules/bd.js | 17 | modules/locaciones.js:14 |
| 19 | modules/rodajes.js | **26** | modules/locaciones.js:18 |
| 20 | modules/perfil-onboarding.js | 24 | modules/config.js:19 |
| 21 | modules/invitaciones.js | **31** | modules/config.js:20 |
| 22 | modules/info-proyecto.js | 27 | modules/admin.js:15 |
| 23 | modules/admin.js | **32** | modules/config.js:21 |
| 24 | modules/config.js | 20 | modules/buscador.js:14 |
| 25 | modules/buscador.js | 19 | lib/boot.js:21 |
| 26 | lib/boot.js | **36** | modules/locaciones.js:19 |
| 27 | modules/locaciones.js | 14 | modules/dal.js:29 |
| 28 | modules/tareas.js | 29 | modules/plan-rodaje.js:15 |
| 29 | modules/plan-rodaje.js | 16 | modules/legal.js:22 |
| 30 | modules/legal.js | 15 | modules/dal.js:31 |
| 31 | modules/dal.js | 21 | modules/persistencia-local.js |
| 32 | modules/persistencia-local.js | 23 | modules/presupuesto-cotizacion.js:16 |
| 33 | modules/presupuesto-cotizacion.js | 13 | modules/kanban.js:22 |
| 34 | modules/kanban.js | 11 | **main.js:16** |
| 35 | modules/documentos.js | 25 | main.js:30 |
| 36 | modules/crew.js | 28 | main.js:33 |
| 37 | modules/cargos.js | 30 | main.js:35 |
| 38 | modules/espacio.js | 34 | main.js:39 |
| 39 | modules/calculadoras.js | 35 | main.js:40 |
| 40 | main.js | (entrada) | — |

### 2.2 Lectura estructural

- **La línea 16 de main.js (`import './modules/kanban.js'`) dispara la evaluación de 21 módulos** (eval #14–#34): kanban → presupuesto-cotizacion → persistencia-local → dal, y dal arrastra plan-limites, locaciones, bd, legal…, incluida **lib/boot.js**. Solo 16 de las 36 entradas del manifiesto disparan evaluación nueva; las 20 restantes (líneas 17-29, 31-32, 34, 36-38 de main.js) son no-ops de enlace: sus módulos ya evaluaron dentro del subárbol de kanban.
- **Adelantos mayores** (eval# vs manifiesto#): `plan-limites` #14 vs #33 (adelanto 19), `invitaciones` #21 vs #31 (10), `boot.js` #26 vs #36 (10), `admin` #23 vs #32 (9), `rodajes` #19 vs #26 (7), `gastos` #17 vs #22 (5), `info-proyecto` #22 vs #27 (5).
- **Por qué importa**: todo el código top-level de la sección 5 (los 108 `define()`, los 25 `registrarAcciones()`, los listeners de documento de boot.js:61 y espacio.js:91, el gobierno del veil de boot.js:690-693, el `goWire()` de gastos.js:1591) corre en la posición **efectiva**, no en la del manifiesto. Ejemplo concreto: el keydown global de undo/redo (boot.js:61) y el estado del veil quedan instalados en eval #26 — durante la resolución de la línea 16 del manifiesto, veinte líneas "antes" de donde el manifiesto sugiere. Quien razone orden por el manifiesto se equivoca en 21 de 36 posiciones.
- **Ciclos**: 49 aristas de retroceso (script `ciclos.py`; p. ej. `perfil-onboarding.js → lib/boot.js`, `config.js → lib/boot.js`, `bd-excel.js → bd.js`, `dal.js → kanban.js`). El sistema funciona porque **todo símbolo importado a través de una arista de ciclo es una function declaration** (hoisted en la creación del entorno de módulo, accesible antes de que el cuerpo del productor evalúe) y **solo se invoca en runtime post-arranque**. Ese invariante es el que documenta ganchos.js:12-13 ("Todos los define() corren al EVAL del productor…; toda invocación es runtime post-arranque — nunca hay carrera"), pero para los imports directos en ciclo nada lo verifica mecánicamente (ver Hallazgo H7). Caso ilustrativo verificado: `ui.js` (eval #12) importa `valor` y consume `valor('MODULES')` solo dentro de `sectionResponsableHTML` (ui.js:511, runtime), mientras el productor `define('MODULES', MODULES)` corre en nav.js:194 (eval #13) — sin carrera.
- El adelanto documentado en main.js:41 ("hoy ~29 vía perfil-onboarding") **no coincide con el grafo actual**: boot.js evalúa en #26 y su primer importador es `locaciones.js:19` (`import { orgNombre } from '../lib/boot.js';`). La arista perfil-onboarding.js:15 → boot.js es hoy una arista de retroceso (boot ya está en curso cuando perfil-onboarding evalúa, vía boot→buscador→config→perfil-onboarding).

---

## 3. `lib/boot.js` (737 líneas): secuencia de boot paso a paso

### Fase 0 — eval del módulo (posición efectiva #26, antes de `DOMContentLoaded`)

| Línea | Qué corre |
|---|---|
| 34 | IIFE: `localStorage.getItem('takeos_usuario_actual')` → `setUsuarioActual(u)` (restaura el nombre cacheado) |
| 61-76 | `document.addEventListener('keydown', …)`: `Cmd/Ctrl+,` → abre/cierra config vía `gancho('_configPanelOpen')`/`gancho('openConfigPanel')`; `Cmd/Ctrl+Z` → `undoLast()` (solo fuera de INPUT/TEXTAREA/contentEditable); `+Shift` → `redoLast()` |
| 77 | `const AUTH_RETORNO_OAUTH = /[#?&](access_token\|refresh_token\|code)=/.test(window.location.hash + ' ' + window.location.search);` — la detección de retorno OAuth se computa **en eval** |
| 80 | captura `?invitacion=<token>` → `sessionStorage.setItem('takeos_inv_pendiente', …)` (sobrevive el viaje a Google) |
| 84 | `const AUTH_TTL_HORAS = 12;` |
| 91, 97 | `window.logoutTakeOS = async function () {…}` y `window.confirmLogout = function () {…}` |
| 690-693 | Gobierno del veil CSS-first: si `sessionStorage['takeos_sin_veil']==='1'` remueve el `#bootVeil` estático (index.html:1279, nace visible); si no, `_bootVeil('')` (boot.js:351; se autodesactiva a los 1300 ms, L361: "cortina, no muro") |
| 696 | `window.cloudGate = cloudGate;` |
| 699-701 | `registrarAcciones('boot', { cgEnter: … })` (Enter en el campo contraseña del login) |
| 705-725 | `registrarAcciones('app', {…})` — las 15 acciones de los estáticos de index.html: `modulo`, `controlRoom`, `swToggle`, `buscar`, `config`, `undo`, `importSave`, `bell`, `notifTodas`, `logout`, `importProyectoBtn`, `importProyecto`, `papelera`, `cfo`, `nuevoProyecto` |
| 728-737 | 10 × `define()`: `_bootCoverHide`, `_firstVisibleModule`, `_setOrgActiva`, `aplicarMarcaOrg`, `applyModuleReadonly`, `applyPermisosUI`, `currentUser`, `orgNombre`, `renderTopbarUser`, `setCurrentUser` |

### Fase 1 — `DOMContentLoaded` (boot.js:667-687)

Orden interno exacto: (1) versión en `#brandVer` (L668, desde `TAKEOS_VERSION`, state.js:222); (2) `aplicarMarcaOrg()` (L669; definida en L224); (3) `aplicarUsuario()` (L670; `export function aplicarUsuario()` L238); (4) `applyStoredTheme()` (L671, de ui.js); (5) `renderMetrics()` (L672); (6) `renderKanban()` (L673) — **primer render, con `PROJECTS` aún vacío**; (7) `setupTooltipListeners()` (L674); (8) `document.addEventListener('change', markDirty, true)` y `'input'` con guard `STATE.dirty` (L678-679, captura); (9) `window.addEventListener('beforeunload', () => { if (STATE.dirty) autosaveNow(); })` (L681); (10) `cloudGate(() => { iniciarSesionTakeOS(); })` (L686).

### Fase 2 — `export async function cloudGate(onUnlock)` (boot.js:368-550): el LOGIN real

- L369-370: `const client = supabaseInit();` — si `null`, `onUnlock()` directo (fail-open documentado: "sin Supabase, no bloqueamos").
- **Rama retorno de OAuth** (L380-405, si `AUTH_RETORNO_OAUTH`): poll de `client.auth.getSession()` hasta 15×200 ms; con sesión → sella `localStorage['takeos_auth_at']=Date.now()` y `['takeos_auth_uid']=sess.user.id` (L392-393), limpia el query OAuth con `history.replaceState` (L397-400), `_bootVeil('Cargando tus proyectos…'); onUnlock(); return;` (L402).
- **Rama sesión restaurada** (L407-439): `client.auth.getUser()` — validación **contra el servidor** (comentario L407-412: a diferencia de `getSession()`, detecta usuario borrado/revocado). Entra sin login solo si `uid === takeos_auth_uid` **y** `Date.now() - takeos_auth_at < AUTH_TTL_HORAS*3600*1000` (L421-428). Si no: `client.auth.signOut({ scope: 'local' })` + borrado de sellos (L432-433, 437-438).
- **Overlay de login** `#cloudGate` (L445-473): botón Google → `client.auth.signInWithOAuth({ provider: 'google', options: { redirectTo, queryParams: { prompt: 'select_account' } } })` (L485-494); email+contraseña → `client.auth.signInWithPassword({ email: correo, password: clave })` (L520), con sellado en el mismo formato que Google (L538) y remoción del overlay + `_bootVeil` + `onUnlock()` (L539-541).

### Fase 3 — `async function iniciarSesionTakeOS()` (boot.js:646-665): onboarding

`_bootCoverShow('Cargando tu espacio…')` (L647; `export function _bootCoverShow(msg)` L193, con red de seguridad `setTimeout(_bootCoverHide, 10000)` L209) → `client.auth.getUser()` → consulta `user_profiles` (`select('user_id, nombre, apellido').eq('user_id', uid).maybeSingle()`, L654) → con perfil: `setUserNombre/setUserApellido` + `aplicarUsuario()` (L656); sin perfil: `gancho('abrirPerfilUsuario')(true, function () { resolverEspacioYArrancar(); }); return;` (L658). Cualquier fallo continúa a `resolverEspacioYArrancar()` (L664).

### Fase 4 — `export async function resolverEspacioYArrancar()` (boot.js:583-635): espacio multi-org

En orden: `?espacio=demo` → `gancho('renderEspacioUsuario')(valor('ESPACIO_DEMO'))` (L586); `?plan=(gratis|rodaje|produccion)` → limpia URL + `gancho('abrirFlujoCrearProductora')(_plan)` (L592-599); sin cliente/uid → `_renderEspacioSeguro(email)` (L605, 609; L215: "Jamás cae al Control Room"); `takeos_inv_pendiente` → `gancho('abrirInvitacionRecibida')(_invTok)` (L613); consulta `memberships` (`.select('organization_id, tipo, profile_id, estado, organizations(nombre)').eq('user_id', uid).eq('estado','activo')`, L614-616) + filtro de membresías colgantes (L621) + `rpc('mis_invitaciones')` (L624). Decisión: 0 filas → espacio personal con CTA productora (L625); **1 fila interna, sin `?espacio=1` ni invitaciones → `setTieneEmpresa(true); _bootCoverShow('Entrando a tu productora…'); _setOrgActiva(rows[0].organization_id); arrancarTakeOS();`** (L626); resto (multi-org o externo) → `gancho('renderEspacioUsuario')(gancho('_espConstruir')(rows, email))` (L629).

### Fase 5 — `export function arrancarTakeOS()` (boot.js:573-579): carga de datos

Guard del invariante V11.13.0 (L576-577): sin `_TIENE_EMPRESA` y sin `sessionStorage['takeos_ir_proyecto']` → `resolverEspacioYArrancar(); return;`. Luego la **cadena DAL secuencial** (L578, una sola expresión de promesas):

`dalBootTaxRates()` → `dalBootContactos()` (dal.js:234) → `dalResolveIdentidad()` (dal.js:476) → `dalLoadPermisos()` (dal.js:541) → `dalBootPersonasExternos()` (dal.js:256) → `dalBootLocaciones()` (dal.js:330) → `dalBootLegal()` (dal.js:390) → `dalBootPerfil()` (dal.js:455) → `dalBootProyectos()` (dal.js:1313) → `notifInit()` → `gancho('_cpTourInicialQuizas')()` → `setTimeout(_pdCookiesBootCheck, 1200)` **[roto — Hallazgo H1]** → `.catch(…{ _bootCoverHide(); })`.

`dalLoadPermisos` cierra el circuito de permisos: `setTakeosPerfil({ codigo, nombre, tipo, profileId, contactId })` (dal.js:555), matriz `profile_permissions` → `setTakeosAcceso(acc)` (dal.js:570), y aplica a la UI vía `gancho('renderTopbarUser')(); gancho('applyPermisosUI')();` (dal.js:571-572). App interactiva: los listeners de delegación llevan activos desde eval #11; el contenido llega con `dalBootProyectos` re-pintando kanban.

Cambio de organización en caliente: `export function _setOrgActiva(orgId)` (boot.js:130-185) — valida UUID (L133), y si `s !== ORG_ID`: flush de guardado pendiente (`dalTouchProyecto`+`dalFlushProyectos`, L146-147), **demolición del estado en memoria** (`PROJECTS.length=0; TRASH.length=0`, vaciado de BD_*, `EMPRESA_PERFIL`, L148-153), `setSource('…','pending')` ×5 (L154-156), `setTakeosAcceso(null)` fail-closed (L157), `dalResetOrg()` + `window._persisResetOrg()` (L159-160), reset de vista inline (L169-178), `setOrgId(s)` + `localStorage['takeos_org_activa']` (L181-182).

---

## 4. `lib/auth.js` (82 líneas): gates de acceso/roles — y dónde vive el resto del flujo

Precisión de alcance: **auth.js no contiene login/sesión/logout** — solo la capa de autorización (Gate B, capa de cliente). El login es `cloudGate` (boot.js:368), el logout `window.logoutTakeOS` (boot.js:91) y `window.confirmLogout` (boot.js:97, conectado al topbar vía acción delegada `app.logout`, boot.js:719), y la carga de identidad/permisos es `dalResolveIdentidad`/`dalLoadPermisos` (dal.js:476/541). Firmas reales de auth.js:

```js
export function authNivel(modCode) {            // L35 — 'none' | 'L' | 'E'; fail-closed: !TAKEOS_ACCESO → 'none'
export function authNivelModulo(appKey) {       // L45 — appKey sin mapear en MODULE_PERM_CODE → 'none' (Gate B fail-closed)
export function authPuedeVer(appKey) { return authNivelModulo(appKey) !== 'none'; }   // L50
export function authEsAdmin() { return TAKEOS_PERFIL && (TAKEOS_PERFIL.codigo === 1 || TAKEOS_PERFIL.nombre === 'Administrador'); }  // L51
export function _puedeEditarResponsables() {    // L55 — fail-open: sin perfil no restringe; codigo 1|2
export function _puedeEditarTareas() { return authNivel('tareas') === 'E'; }           // L61
export function authPuedeGuardarProyecto() {    // L65 — fail-open si !TAKEOS_ACCESO; si no, 'E' en alguno de ['presupuesto','cotizacion','info_proyecto','reporte_cierre']
export function authPuedeGuardarOperaciones() { // L69 — fail-open si !TAKEOS_ACCESO; si no, authNivel('operacion_creatividad')==='E'
export function _authBlockWriteToast() {        // L74 — toast antispam (ventana de 4000 ms vía _authBlockToastAt)
```

**Contratos explícitos**:
- `MODULE_PERM_CODE` (auth.js:13-31): 17 entradas appKey→código de permiso (contadas con `sed -n '13,31p' lib/auth.js | grep -c ":"` → 17). Invariante documentado (L40-44): "Todas las claves vivas del registro MODULES y del sidebar están en MODULE_PERM_CODE"; una appKey sin mapear se **niega** ('none').
- **Asimetría deliberada fail-closed/fail-open**, documentada en dal.js:517-533: la visibilidad/lectura niega por defecto (`authNivel` con matriz null → 'none'); los guards de **escritura** (`authPuedeGuardar*`) son fail-open con `TAKEOS_ACCESO === null` porque "la seguridad real de escritura la cierra el RPC SECURITY DEFINER (Gate C); esa guarda de cliente es solo UX".
- Estado consumido: `TAKEOS_PERFIL`/`TAKEOS_ACCESO` importados de state.js (auth.js:12); única vía de escritura: `setTakeosPerfil`/`setTakeosAcceso` (state.js:234-235), llamados solo por `dalLoadPermisos` (dal.js:555, 570) y el reset de `_setOrgActiva` (boot.js:157).

**Puntos de aplicación de los gates**: `navigateToModule` (nav.js:13-20: `if (!authPuedeVer(moduleKey))` → toast + fallback a `gancho('_firstVisibleModule')()`); `applyPermisosUI()` (boot.js:275-301: oculta `.sidebar-item[data-module]`, badge 'L' de solo lectura, botones "nuevo proyecto"/import gobernados por `authNivel('crear_proyecto')==='E'`, CFO por `authNivel('finanzas_consolidada')!=='none'`); `applyModuleReadonly(appKey)` (boot.js:312-325: clase `mod-readonly` + banner, invocada tras cada render vía `gancho('applyModuleReadonlyʼ)` en nav.js:245); `_firstVisibleModule()` (boot.js:305-309).

**Sesión — invariantes**: sello de doble clave `takeos_auth_at`/`takeos_auth_uid` (misma forma en OAuth boot.js:392-393 y contraseña boot.js:538 — el comentario L528-537 documenta el bug BUG-7 que causó tener formatos distintos); TTL 12 h (`AUTH_TTL_HORAS`, boot.js:84); validación server-side con `getUser()` para sesiones restauradas (boot.js:413); autenticación obligatoria en cada entrada fuera de la ventana TTL (política V11.2.1, boot.js:372-378). `logoutTakeOS` (boot.js:91-95): `sb.auth.signOut()` + borrado de `takeos_auth_at/uid`, `takeos_usuario_actual/uid` + `location.reload()`.

---

## 5. Código a NIVEL DE MÓDULO (corre al eval, antes de DOM ready), por archivo

Barrido con grep anclado a columna 0 (`^define(|^registrarAcciones(|^document\.addEventListener|^window\.addEventListener|^window\.X=|^\(function|^try {|^\[`) más lectura directa; el estilo del repo pone todo el top-level en columna 0. Totales: **108 `define()`** top-level (`grep -hc "^define(" src/lib/*.js src/modules/*.js | paste -sd+ | bc` → 108), **25 `registrarAcciones()`** en 24 namespaces (`grep -h "^registrarAcciones(" … | wc -l` → 25; `'pre'` aparece 2×), **50 asignaciones `window.X =`** en columna 0 (`grep -hE '^window\.[A-Za-z_$]' … | wc -l` → 50) más 11 espejos same-line en state.js.

**lib/ (en orden de eval):**
- `helpers.js` (#1): puro, 0 imports, sin top-level con efectos.
- `supabase.js` (#2): `console.info('[supabase] base:', SUPABASE_URL)` (L13); **`if (!('sb' in window)) window.sb = null;`** (L16) — garantiza que la propiedad global exista desde el eval ("los guards `if (!sb)` del DAL nunca pueden lanzar ReferenceError"). `SUPABASE_URL/KEY` desde `import.meta.env` (L11-12).
- `rates.js` (#3): defaults tributarios como `export let` (L12-17); llamada `_espejo()` (L22) a una función **vacía** (L18-21).
- `state.js` (#4): `window.DAL_SESSION_UID = null; window.DAL_SESSION_EMAIL = '';` (L52-53); `export let USUARIO_ACTUAL = ('USUARIO_ACTUAL' in window) ? USUARIO_ACTUAL : '';` (L54 — ver H2); 11 espejos same-line `export const X = …; window.X = X;` (L92, 97, 136-140, 149, 157, 161, 176: STATES_WITH_*, BD_CONTACTOS, BD_EMPRESAS_BYID, BD_PERSONAS, BD_TALENTOS, BD_EMPRESAS, BD_LOC, PROJECTS, TRASH, EMPRESA_PERFIL); `window.STATE = STATE;` (L226).
- `catalogos.js` (#5): hoja pura, 0 imports, sin efectos.
- `ganchos.js` (#6): solo `const REGISTRO = {}` (L16).
- `modelo.js` (#7): `window._clientUuid = _clientUuid;` (L424).
- `data.js` (#8): sin efectos; nota: import **a mitad de archivo** (L69, de catalogos.js) con re-export — hoisted, cosmético.
- `auth.js` (#9): solo `const MODULE_PERM_CODE` (L13) y `let _authBlockToastAt = 0` (L73).
- `calc.js` (#10): sin top-level con efectos.
- `delegacion.js` (#11): **instala los 13 listeners de documento** — 11 en burbuja (`click,input,change,keydown,dblclick,mousedown,paste,submit,dragover,dragleave,drop`, L54-56) y 2 en captura (`focus,blur`, L57-59). Toda la delegación de la app está viva desde eval #11.
- `ui.js` (#12): `registrarAcciones('ui', {…})` (L785) — acciones universales (cerrar/backdrop/modal/combobox).
- `nav.js` (#13): **`define('MODULES', MODULES);`** (L194) — productor del registro de 16 módulos (contadas: 16); consumido por ui.js:511 vía `valor('MODULES')` en runtime.
- `boot.js` (#26): ver Fase 0 completa arriba (IIFE L34, keydown L61, `AUTH_RETORNO_OAUTH` L77, token invitación L80, `window.logoutTakeOS/confirmLogout` L91/97, veil L690-693, `window.cloudGate` L696, `registrarAcciones('boot'/'app')` L699/705, 10 `define()` L728-737).

**modules/ (en orden de eval):**
- `plan-limites.js` (#14): `registrarAcciones('plan', …)` (L105).
- `bd-excel.js` (#15): `window._codigoBancoSBIF/_nombreBancoOficial` (L745-746); 11 `define()` (L749-759).
- `notificaciones.js` (#16): `window.ntfSetChannel/ntfSetEditChannel` (L690, 692); `registrarAcciones('ntf', …)` (L699); `define('renderNotificaciones', …)` (L734).
- `gastos.js` (#17): **IIFE `(function goWire() {…})()`** (L1591-1612) — muta `MODULES` en eval: `MODULES['gastos'].render = renderGastos` (L1598) y agrega `MODULES['cfo']` (L1602-1610; el registro runtime queda en 17 entradas). Además `window.goGastoHint/goLineaTieneCaja/openGlobalCFO/renderGastos/goVerComprobante/goCfoVer` (L1617-1625), `registrarAcciones('go', …)` (L1628), 5 `define()` (L1691-1695). Orden garantizado por `import { MODULES … } from '../lib/nav.js'` (gastos.js:17), no por el manifiesto (ver H4).
- `bd.js` (#18): 5+ `window.*` (L1122-1128), `registrarAcciones('bd', …)` (L1131), 6 `define()` (L1190-1195).
- `rodajes.js` (#19): `registrarAcciones('rodajes', …)` (L218), `define('renderRodajes', …)` (L226).
- `perfil-onboarding.js` (#20): `window._regionCanonica` (L602), 2 `define()` (L605-606).
- `invitaciones.js` (#21): `registrarAcciones('inv', …)` (L207), `define('abrirInvitacionRecibida', …)` (L215).
- `info-proyecto.js` (#22): `window.updateInfoField` (L548), `registrarAcciones('info', …)` (L554), 3 `define()` (L591-593).
- `admin.js` (#23): `window.exportSupabaseBackup/toggleAdminMode` (L389-390), 4 `define()` (L393-396).
- `config.js` (#24): `window._cpCerrar/_cpSiguiente/_cpTourNext/_orgLogos` (L2114-2119), `registrarAcciones('cfg', …)` (L2143), 11 `define()` (L2161-2171, incluye `define('_configPanelOpen', function () { return _configPanelOpen; })` — cierre sobre estado vivo).
- `buscador.js` (#25): `registrarAcciones('buscador', …)` (L91).
- `locaciones.js` (#27): `window.locNombre` (L840), `registrarAcciones('loc', …)` (L851), 4 `define()` (L906-909).
- `tareas.js` (#28): `window.mentionBlur/mentionInput` (L306-307), `registrarAcciones('tm', …)` (L310), 8 `define()` (L330-338).
- `plan-rodaje.js` (#29): `window.renderHojaLlamado` (L1403), `registrarAcciones('pr', …)` (L1463), 10 `define()` (L1481-1490).
- `legal.js` (#30): `window.legalRep` (L884), `registrarAcciones('lgl', …)` (L889), 2 `define()` (L924-925).
- `dal.js` (#31): 3 `define()` (L1897-1899). Sin listeners ni window-writes top-level.
- `persistencia-local.js` (#32): **`window._persisResetOrg = function () {…}`** (L25 — lo invoca `_setOrgActiva`, boot.js:160), `window.openSnapshotsModal` (L623), `registrarAcciones('snap', …)` (L626), 5 `define()` (L632-636).
- `presupuesto-cotizacion.js` (#33): `window._clientUuid` (L4335 — duplica el de modelo.js:424 con el mismo valor), `registrarAcciones('pre', …)` **dos veces** (L4444 y L4471; legal por el merge `Object.assign` de delegacion.js:17), 3 `define()` (L4478-4480).
- `kanban.js` (#34): `window.newProject` (L347), `registrarAcciones('kanban', …)` (L350), `define('_lastViewSave', …)` (L360) y siguientes.
- `documentos.js` (#35): `registrarAcciones('doc', …)` (L213), `define('renderDocumentos', …)` (L224).
- `crew.js` (#36): `registrarAcciones('crew', …)` (L347), 2 `define()` (L361-362).
- `cargos.js` (#37): `registrarAcciones('cargo', …)` (L426), 4 `define()` (L447-450).
- `espacio.js` (#38): **`try { document.addEventListener('click', function (e) {…}); } catch (e) {}`** (L91 — cierra el menú `#eswMenu` al click fuera; segundo listener de documento fuera de delegacion.js/boot.js), `registrarAcciones('esp', …)` (L429), 7 `define()` (L444-450, incluye `define('ESPACIO_DEMO', ESPACIO_DEMO)` — valor, no función).
- `calculadoras.js` (#39): 5 `window.*` (L621-625), `registrarAcciones('calc', …)` (L629), 6 `define()` (L650-655).
- `main.js` (#40): los 6 puentes + `console.info` (§1.2).

**Invariante de arranque resultante**: al terminar el eval de main.js (antes de `DOMContentLoaded`) están instalados: 13+2 listeners de despacho (delegación), el keydown global de boot, el click-outside de espacio, los 108 ganchos, los 25 registros de acciones y todos los puentes window — y ninguna acción de usuario pudo haberse despachado aún porque el DOM estático usa exclusivamente `data-accion` (CSP sin `unsafe-inline`).

---

## Hallazgos

1. **[BUG, confirmado] `_pdCookiesBootCheck` es un ReferenceError silenciado en la cadena de boot** — boot.js:578: `…​.then(function(){ try { setTimeout(_pdCookiesBootCheck, 1200); } catch (e) {} })`. boot.js **no importa** config.js (diferido anti-ciclo, boot.js:5-7), no existe ningún productor `window._pdCookiesBootCheck` (`grep -rn "_pdCookiesBootCheck" src/` → solo el export en config.js:2060, el `define()` en config.js:2164, el import legítimo de espacio.js:13 y esta referencia), y los módulos son modo estricto: el identificador a pelo lanza `ReferenceError`, que el `try/catch` traga. Consecuencia: el check del banner de cookies tras `arrancarTakeOS()` (ruta de entrada directa a productora única) **nunca corre**; solo corre por la ruta espacio.js:348. El fix esperable es `gancho('_pdCookiesBootCheck')`.
2. **[BUG latente] TDZ auto-referente en state.js:54** — `export let USUARIO_ACTUAL = ('USUARIO_ACTUAL' in window) ? USUARIO_ACTUAL : '';`. El `USUARIO_ACTUAL` del lado derecho resuelve léxicamente al binding que se está declarando (no a `window.USUARIO_ACTUAL`): si algún script clásico llegara a definir `window.USUARIO_ACTUAL` antes del eval de state.js (#4), la app moriría con ReferenceError en pleno arranque. Hoy la condición es siempre falsa (no quedan scripts inline por la CSP), pero el código dice lo contrario de lo que hace; la intención evidente era `window.USUARIO_ACTUAL`.
3. **[Comentario stale, orden] main.js:41** — afirma que el eval de boot.js se adelanta "hoy ~29 vía perfil-onboarding". Medido: eval **#26**, disparado por **locaciones.js:19** (`import { orgNombre } from '../lib/boot.js';`); la arista perfil-onboarding→boot es hoy de retroceso. El comentario que documenta el contrato de orden más delicado del manifiesto está desactualizado.
4. **[Comentario stale, orden] main.js:15 y gastos.js:3-10 refieren `window.MODULES`, que ya no existe** — "goWire lee window.MODULES en eval" / "goWire sigue leyendo MODULES en eval: nav (15) siempre antes que gastos". `grep -rn "window.MODULES" src/` → solo esos comentarios. goWire lee el **import** `MODULES` (gastos.js:17), de modo que el orden nav→gastos lo garantiza ESM por la propia arista, y la restricción de posición en el manifiesto (⚠ de main.js:15) es hoy inoperante. Los guards `typeof MODULES !== 'undefined'` y `typeof EMPRESA_PERFIL !== 'undefined'` (gastos.js:1594, 1596) son reliquias: ambos son imports siempre definidos.
5. **[Código muerto] rates.js:18-22** — `function _espejo() { }` vacía, invocada en L22 (eval) y L48 (post-carga de tasas). Residuo del apagado de espejos window (D4c).
6. **[Acople window residual] `sb` a pelo sin import** — dal.js (68 usos, p.ej. dal.js:477), boot.js (4 usos, p.ej. boot.js:92, 604, 649) y rates.js (2 usos, rates.js:25) leen el global `sb`, sosteniéndose en `if (!('sb' in window)) window.sb = null;` (supabase.js:16). Es un patrón documentado, pero la corrección de tres archivos depende de una línea de un cuarto: si se elimina, todo guard `if (!sb)` pasa de "falsy" a ReferenceError. La exportación `export let sb` (supabase.js:15) existe y ya la consumen 11 módulos vía import; dal/boot/rates quedaron a medio migrar.
7. **[Deuda estructural] 49 aristas de import en ciclo (de 88 aristas del árbol DFS)** — medido con DFS (aristas hacia módulos con eval en curso; lista completa en §2.2, p.ej. `bd-excel.js→bd.js`, `config.js→lib/boot.js`, `dal.js→kanban.js`). El sistema depende del invariante no verificado "solo function declarations cruzan aristas de ciclo, y solo se invocan post-eval": un futuro `export const` consumido en eval a través de cualquiera de esas 49 aristas es un TDZ en producción. Las compuertas del proyecto validan ganchos (105/105 según `4c8067b`) pero no este invariante de los imports directos.
8. **[Comentarios stale] auth.js:1-7 y auth.js:81** — la cabecera dice que las funciones "Leen el estado (…) y showToast desde window (puenteados en Etapa 1)" y que "Al final se auto-puentean a window"; hoy son imports reales (auth.js:10, 12) y la sección "Puentes a window" (L81-82) está vacía.
9. **[Menor] `registrarAcciones('pre', …)` duplicado** — presupuesto-cotizacion.js:4444 y 4471. Funciona por el merge `Object.assign(ACCIONES[ns] || {}, mapa)` (delegacion.js:17), pero es el único namespace partido en dos registros y un choque de claves entre ambos bloques se resolvería por silencioso "último gana".
10. **[Menor, coherencia] `TAKEOS_VERSION = 'V11.14.0'`** (state.js:222) mientras comentarios recientes del mismo árbol citan V11.15.0 como implementado (boot.js:43, auth.js:40, espacio.js:348) — o la constante quedó sin subir o el versionado de comentarios corre por delante del release; esta constante se muestra en el login (boot.js:472) y en `#brandVer` (boot.js:668).