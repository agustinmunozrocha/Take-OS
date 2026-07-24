# Informe de arquitectura — Superficie global residual, seguridad y CSP
**Repo:** `/home/juandlc/Trabajo/Take-OS` · rama `etapa4-integracion` · app en `frontend/` (25.327 LOC JS en `src/`, contado con `find src -name "*.js" | xargs wc -l`). Post-desacople: 0 `onclick` en `frontend/index.html` (`grep -c onclick` → 0), 32 `data-accion` estáticos, 110 `define(`, 194 `gancho(`, 7 `valor(` (grep sobre `src/`).

---

## 1. Censo EXACTO de `window`

### 1.a Totales

| Métrica | Valor | Comando |
|---|---|---|
| Asignaciones `window.X =` | **73** | `grep -rn "window\.[A-Za-z_$][A-Za-z0-9_$]* *=" frontend/src --include="*.js" \| grep -v "==" \| wc -l` |
| Referencias totales `window.<prop>` | **194** | `grep -rhoE "window\.[A-Za-z_\$][A-Za-z0-9_\$]*" frontend/src --include="*.js" \| wc -l` |
| — de las cuales API estándar del navegador | **75** | suma del `uniq -c` (`location` 20, `open` 10, `prompt` 8, `localStorage` 8, `scrollTo` 6, `innerWidth` 5, `crypto` 4, `confirm` 4, `addEventListener` 3, `innerHeight` 2, `removeEventListener`/`getSelection`/`print`/`scrollX`/`scrollY` 1 c/u) |
| — propiedades propias de la app | **119** (incluye ~12 menciones dentro de comentarios: `window.X` genérico ×6, `window.MODULES` ×2 —solo comentarios en `main.js:15,40`—, `window.DEFAULT_*` ×1, etc.) | mismo `uniq -c` |

### 1.b Las 73 asignaciones, clasificadas

**Grupo A — Estado window-resident VIVO (sesión / época / cliente). El contrato: `lib/state.js` pre-crea la propiedad al eval para que las escrituras *bare* en modo estricto de otros módulos no lancen `ReferenceError`; los lectores son identificadores desnudos que resuelven al objeto global.**

| Prop | Escritura(s) | Lectores reales | Clase |
|---|---|---|---|
| `window.sb` | `lib/supabase.js:16` (`if (!('sb' in window)) window.sb = null;`), `lib/supabase.js:22` (`window.sb = sb;` — "también disponible en la consola para pruebas") | 40 usos desnudos `sb.` en `modules/dal.js` (`grep -c "\bsb\." dal.js` → 40; dal.js **no** importa de `supabase.js`), guards `typeof sb !== 'undefined'` en `lib/boot.js:604,649`, `modules/perfil-onboarding.js:76,536` | sesión/cliente (load-bearing) |
| `window.DAL_SESSION_UID` / `window.DAL_SESSION_EMAIL` | `lib/state.js:52-53` (defaults); escrituras desnudas `modules/dal.js:482-483` | 13 + 3 lecturas desnudas (`dal.js:491,504,506,511,513,542,548,675,704`; `config.js:460,465,596,611`) | sesión (load-bearing) |
| `window.__TAKEOS_USER` | `modules/dal.js:492,513,559` | `lib/boot.js:255` | sesión (ver §2) |
| `window.__TAKEOS_DATA_SOURCE` | `modules/dal.js:244` | **0 lectores** en todo el repo (`grep -rn "__TAKEOS_DATA_SOURCE"` → solo la escritura) | telemetría/diagnóstico |
| `window._ORG_EPOCA` | `modules/dal.js:1857` | `modules/dal.js:1851` | época (ver §2) |

**Grupo B — Bridges de función con lector runtime real (9). El lector es o `window.`-explícito o un guard `typeof X === 'function'` sobre global desnudo (patrón "arista diferida" anti-ciclo: si el módulo productor no cargó, la feature se degrada en silencio).**

| Asignación | Lector |
|---|---|
| `lib/boot.js:91` `window.logoutTakeOS = async function () {` | `lib/boot.js:104` (y consola, documentado en `boot.js:89`: "Por ahora se llama desde la consola") |
| `lib/boot.js:97` `window.confirmLogout = function () {` | `lib/boot.js:719` (acción `app.logout`) — auto-consumo vía global |
| `modules/persistencia-local.js:25` `window._persisResetOrg = function () {` | `lib/boot.js:160` `if (window._persisResetOrg) window._persisResetOrg();` |
| `modules/bd.js:1126` `window.crewAddToBD = crewAddToBD;` | `lib/ui.js:162` `if (typeof crewAddToBD === 'function') { gancho('crewAddToBD')(nombre); }` |
| `modules/bd-excel.js:745` `window._codigoBancoSBIF = _codigoBancoSBIF;` | `lib/modelo.js:23`, `lib/ui.js:362` (guards `typeof`) |
| `modules/config.js:2119` `window._orgLogos = _orgLogos;` | `modules/presupuesto-cotizacion.js:4141` (`typeof _orgLogos === 'function' ? valor('_orgLogos')()…`) |
| `modules/gastos.js:1618` `window.goLineaTieneCaja = …` | `modules/presupuesto-cotizacion.js:740` (guard `typeof`) |
| `modules/plan-rodaje.js:1403` `window.renderHojaLlamado = …` | `modules/presupuesto-cotizacion.js:1117` (guard `typeof` + llamada vía `gancho`) |
| `modules/perfil-onboarding.js:602` `window._regionCanonica = _regionCanonica;` | `lib/ui.js:353` (guard `typeof` + `gancho`) |

**Grupo C — Bridges de función SIN lector runtime (muertos / API de consola), 36 asignaciones.** Verificado con script Python que cruza cada nombre contra imports/`define`/`gancho`/definición local en los 39 archivos de `src`: ninguna referencia desnuda ejecutable. Los strings homónimos en `data-args` NO leen window: despachan por mapas locales — `pre.d` → `_PRE_FN` (`modules/presupuesto-cotizacion.js:4445`: `d: function (a, el, ev) { var f = _PRE_FN[a[0]]; … }`, y `_PRE_FN` mapea a `gancho('openCalculadoraTributaria')` etc., líneas 4426-4440) y `cfg.fn` → `_CFG_FN` (`modules/config.js:2144`).
Lista: `main.js:43-47` (`escapeHtml`, `safeUrl`, `showToast`, `supabaseInit`, `dalBootTaxRates`); `lib/boot.js:696` (`cloudGate`); `lib/modelo.js:424` + `modules/presupuesto-cotizacion.js:4335` (`_clientUuid`, **duplicado**); `modules/admin.js:389-390`; `modules/bd.js:1122-1124,1128`; `modules/bd-excel.js:746`; `modules/calculadoras.js:621-625`; `modules/config.js:2114-2117`; `modules/gastos.js:1617,1619,1621,1624-1625`; `modules/info-proyecto.js:548`; `modules/kanban.js:347`; `modules/legal.js:884`; `modules/locaciones.js:840`; `modules/notificaciones.js:690,692`; `modules/persistencia-local.js:623`; `modules/tareas.js:306-307`.

**Grupo D — Espejos de datos (aliasing por referencia de estado canónico exportado), 18 asignaciones, 0 lectores desnudos (todos los consumidores importan — verificado por script).** `lib/state.js:92,97` (`STATES_WITH_REAL_COST`, `STATES_WITH_LOCKED_BUDGET`), `:136-140` (`BD_CONTACTOS`, `BD_EMPRESAS_BYID`, `BD_PERSONAS`, `BD_TALENTOS`, `BD_EMPRESAS`), `:149,157,161,176,226` (`BD_LOC`, `PROJECTS`, `TRASH`, `EMPRESA_PERFIL`, `STATE`), `main.js:48` (`STATE`, **segunda asignación del mismo objeto**), `lib/data.js:14,38-40` (`LOC_ESTADOS`, `DTE_LABEL`, `DTE_LABEL_SHORT`, `DTE_CON_RETENCION`), `modules/dal.js:931` (`DAL_KNOWN_PROJECT_IDS`). Rol residual: inspección por consola; invariante: son el MISMO objeto que el export (`export const BD_CONTACTOS = {}; window.BD_CONTACTOS = BD_CONTACTOS;` — `state.js:136`), nunca se reasignan.

### 1.c Lecturas `window.X` explícitas restantes (todas)

- `window.__TAKEOS_USER` → `lib/boot.js:255` (fallback de `renderTopbarUser`).
- `window._ORG_EPOCA` → `modules/dal.js:1851` (`function _dalEpoca() { return window._ORG_EPOCA || 0; }`).
- `window._persisResetOrg` ×2 → `lib/boot.js:160` (guard + call).
- `window.XLSX` ×4 → `modules/bd-excel.js:62,65` (lazy-load SheetJS desde cdnjs).
- `window.ExcelJS` ×4 → `modules/bd-excel.js:77,80` (lazy-load ExcelJS).
- `'sb' in window` → `lib/supabase.js:16`.
Además, global de CDN `supabase` (UMD de supabase-js): `lib/supabase.js:20` `if (typeof supabase === 'undefined') …` y `:21` `sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);`.

---

## 2. `__TAKEOS_*` y `_ORG_EPOCA`

- **`__TAKEOS_USER`** (string, nombre a mostrar del usuario autenticado). Escritores: `dal.js:492` (logout de identidad → `''`), `dal.js:513` (identidad resuelta desde `user_profiles`: `gancho('setCurrentUser')(nombreReal); window.__TAKEOS_USER = nombreReal; …localStorage.setItem('takeos_usuario_uid', DAL_SESSION_UID…)`), `dal.js:559` (nombre desde membership→`BD_CONTACTOS`). Lector único: `lib/boot.js:255` — fallback si el scalar `USUARIO_ACTUAL` (state.js) está vacío. Es un canal redundante con `setUsuarioActual()` (`state.js:236`): doble fuente de verdad para el mismo dato.
- **`__TAKEOS_DATA_SOURCE`** (`'supabase'`, `dal.js:244`): flag de una sola escritura tras la primera carga exitosa de contactos; **cero lectores** → puro marcador de diagnóstico de consola ("¿de dónde vinieron los datos?"). El estado funcional equivalente son los scalars `CONTACTS_SOURCE`/`LOCATIONS_SOURCE`/… (`state.js:60-64`, `'pending' → 'supabase'`, contrato fail-safe documentado en `state.js:56-58`: "sin lectura confirmada NO se escribe").
- **Prefijo `__TAKEOS_`**: namespacing anti-colisión sobre el objeto global (convención, no hay registro central).
- **`_ORG_EPOCA`** — contador monotónico de época de la organización activa. Contrato (`dal.js:1846-1854`): `dalResetOrg()` incrementa la época (`dal.js:1857` `window._ORG_EPOCA = _dalEpoca() + 1; // invalida toda cadena de boot en vuelo`) y limpia sets de IDs conocidos + timers; toda cadena async de boot captura `_dalEpoca()` al entrar y aborta tras cada `await` si cambió (p.ej. `dalFlushProyectos`, `dal.js:1873-1877`: `if (_ep !== _dalEpoca()) return;`). Invariante: ninguna escritura remota o merge puede aterrizar con datos de una org anterior.
  **¿Por qué window y no state.js?** Razón deducible: es un artefacto de la fase D0 (commit `91da876 fix(d0): época de organización — blindaje contra cadenas de boot obsoletas`, hallado con `git log -S "_ORG_EPOCA"`), anterior al sistema de ganchos D4; el comentario `dal.js:1850` dice "Lo invoca _setOrgActiva (boot.js) vía window", pero HOY `boot.js:17` **importa** `dalResetOrg` y la llama en `boot.js:159` — es decir, la arista up-edge que justificaba window ya no existe. Productor (`dal.js:1857`) y consumidor (`dal.js:1851`) viven ambos en `dal.js`: podría ser un `let` module-local sin cambio semántico. Residuo, no diseño vigente.

---

## 3. CSP de `index.html` — análisis directiva por directiva

Política única en `frontend/index.html:35` (meta http-equiv; GitHub Pages no permite headers — el propio comentario `index.html:27-30` lo reconoce):

```
default-src 'self'; script-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: blob: https:; connect-src 'self' https://*.supabase.co wss://*.supabase.co; frame-src 'self' blob:; object-src 'none'; base-uri 'self'
```

| Directiva | Permite | Justificación verificada en código |
|---|---|---|
| `default-src 'self'` | fallback estricto (cubre `media-src`, `manifest-src`, `worker-src`* ) | — |
| `script-src 'self' cdn.jsdelivr.net cdnjs.cloudflare.com` | **sin** `'unsafe-inline'` ni `'unsafe-eval'` | jsdelivr: `xlsx@0.18.5` eager (`index.html:1282`) y `@supabase/supabase-js@2` (`index.html:1284`); cdnjs: `xlsx/0.18.5` lazy (`bd-excel.js:64`) y `exceljs/4.4.0` lazy (`bd-excel.js:79`) |
| `style-src 'self' 'unsafe-inline' fonts.googleapis.com` | inline styles + Google Fonts CSS | 1.153 `style="` en JS + 12 en HTML (ver §4); `styles.css:1` hace `@import url('https://fonts.googleapis.com/css2?family=Poppins…')`; decisión documentada en `index.html:11` ("miles de style= — proyecto aparte") |
| `font-src 'self' fonts.gstatic.com` | woff2 de Google | `index.html:1272` preconnect |
| `img-src 'self' data: blob: https:` | cualquier imagen HTTPS | comentario `index.html:23`: "URLs firmadas de Storage" |
| `connect-src 'self' https://*.supabase.co wss://*.supabase.co` | REST + Realtime | cliente en `lib/supabase.js:21` |
| `frame-src 'self' blob:` | iframes de impresión/preview y blobs de PDF | `printViaIframe` (about:blank), preview `srcdoc` (`index.html:24-25`) |
| `object-src 'none'` | bloquea plugins | — |
| `base-uri 'self'` | anti `<base>` hijacking | — |

**Directivas ausentes y su impacto:**
- `frame-ancestors`: **imposible vía `<meta>`** (el navegador la ignora, documentado en `index.html:27-30`) y GH Pages no emite headers ⇒ **clickjacking no mitigado en el hosting actual**. La nota del comentario propone el header pero nadie puede desplegarlo en Pages.
- `form-action`: ausente y **no hereda de `default-src`** por spec ⇒ un `<form action=…>` inyectado podría postear credenciales a cualquier origen. Con `script-src` estricta el vector requiere inyección de marcado (posible en teoría vía los sinks `innerHTML`, ver §6).
- `report-uri`/`report-to`: sin telemetría de violaciones (tampoco desplegable en meta para `report-uri`).
- `upgrade-insecure-requests`: ausente (menor: todo el contenido citado ya es https).
- *`worker-src` cae en `script-src`/`default-src` según navegador; no hay workers en `src/` (no hay `new Worker` — verificable con grep).

**Análisis de superficie (ingeniero de seguridad):**
1. **XSS restante con `script-src` estricta:** `innerHTML`/`doc.write` no ejecutan `<script>` inline y `'unsafe-inline'` está fuera, así que el XSS clásico por interpolación requiere gadgets. Los dos huecos reales: (a) **allowlist de CDN por origen completo** — `cdn.jsdelivr.net` sirve *todo npm* y `cdnjs.cloudflare.com` miles de libs: cualquier inyección de `<script src="https://cdn.jsdelivr.net/npm/<paquete-atacante>">` en marcado persistido que llegue al DOM por parsing de documento (no por innerHTML) ejecutaría; es el bypass de CSP documentado por Google (recomendación: pin por path o nonces/hashes); (b) **cadena de suministro**: `integrity` aparece **0 veces** en `index.html` (`grep -c integrity` → 0) y `@supabase/supabase-js@2` es un **tag flotante de major** (`index.html:1284`) — cada release nueva del major 2 entra a producción sin revisión ni SRI. Los dos loaders dinámicos (`bd-excel.js:64,79`) tampoco fijan `integrity` (que sí es posible en `<script>` creado por DOM).
2. **`style-src 'unsafe-inline'`**: riesgo aceptado y documentado. Vectores residuales: exfiltración por CSS (selectores de atributo sobre `value` + `background-image` — mitigado parcialmente porque `img-src https:` permite el beacon pero `connect-src` no), y UI-redressing interno. Con 1.153 puntos de estilo inline, migrar a nonce es efectivamente el "proyecto aparte" que cita el comentario.
3. **`img-src https:` como canal de exfiltración**: `connect-src` está bien cerrado, pero cualquier contenido controlado por atacante que se renderice como `<img src>` puede exfiltrar datos en el querystring hacia cualquier host https. Asimetría a tener en cuenta.
4. **Iframes de impresión/preview sin `sandbox`:** `printViaIframe` (`modules/plan-rodaje.js:1072-1080`, firma real `export function printViaIframe(html, docTitle)`) crea el iframe con `document.createElement('iframe')`, sin atributo `sandbox`, y hace `doc.open(); doc.write(html); doc.close();` (línea 1080) — `doc.write` **sí ejecuta** `<script>` embebido, y el iframe es same-origin con privilegios completos; la defensa es que about:blank/srcdoc **heredan la CSP del padre** (inline bloqueado) y que el HTML es autogenerado con `escapeHtml`. El preview de cotización (`modules/presupuesto-cotizacion.js:4089` `this.frame.srcdoc = html;`) tampoco lleva `sandbox`. Defensa en profundidad ausente: `sandbox="allow-modals allow-same-origin"` costaría poco.

---

## 4. Superficie de estilos

- **`style="` en código generado (JS):** **1.153** (`grep -rno 'style="' src --include="*.js" | wc -l`). Top: `presupuesto-cotizacion.js` 196, `bd.js` 146, `config.js` 135, `locaciones.js` 85, `gastos.js` 80, `notificaciones.js` 77, `plan-rodaje.js` 61, `legal.js` 61, `calculadoras.js` 42, `cargos.js` 40 (`grep -rco … | sort -t: -k2 -rn`). Más **12** en `index.html` estático (`grep -o 'style="' index.html | wc -l`), p.ej. el `#bootVeil` (`index.html:1279`).
- **`src/styles.css`:** **3.230 líneas** (`wc -l`). Organización por secciones numeradas con banners: `1. VARIABLES` (:3), `2. RESET Y BASE` (:120), `3. LAYOUT SHELL` (:142), `4. CONTROL ROOM` (:311), `5. VISTA DE PROYECTO` (:645), `6. MÓDULOS — COMPONENTES COMUNES` (:876), `8. CSS V5.1 — UX EMOCIONAL Y WIDGETS` (:1746) — **no existe sección 7** con ese formato (`grep -n "   7\." styles.css` → vacío); desde :1752 subsecciones por componente (TOASTS, MODAL, TOOLTIP, NOTIFICACIONES, Plan de Rodaje, Hoja de Llamado…).
- **Tokens/tema:** **55 custom properties** únicas definidas (`grep -oE "\-\-[A-Za-z0-9-]+:" src/styles.css | sort -u | wc -l`) y **1.252 usos** de `var(--…)` (`grep -o "var(--" | wc -l`). **Dark es el tema por defecto**: `:root { color-scheme: dark; … }` (`styles.css:5-6`, paleta AMR documentada en `styles.css:13-16`: "100% basado en tokens"); **tema claro** como override `:root[data-theme="light"]` (`styles.css:77` y `styles.css:2177`). Sin `prefers-color-scheme` (grep → 0 en `src/` e `index.html`): el toggle es manual y persistido — `lib/ui.js:324-325` (`document.documentElement.setAttribute('data-theme', 'light')` / `removeAttribute`) y `export function toggleTheme()` en `lib/ui.js:328`, expuesto en el panel de config (`config.js:111`, botón `data-accion="cfg.fn" data-args="["toggleTheme"]"`) y en el buscador (`buscador.js:34`).
- **Fuentes:** `styles.css:1` importa **Poppins** (única familia usada: `--font-serif`/`--font-sans` en `styles.css:9-10`); `index.html:1274` carga además **Cormorant Garamond + Inter**, que no aparecen en ninguna parte de `src/` (`grep -rn "Cormorant" src` → 0; `grep -rn "'Inter'" src` → 0) — carga muerta (ver Hallazgos).

---

## 5. Manejo de secretos

- **Inyección:** `lib/supabase.js:11-12` — `const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL; const SUPABASE_KEY = import.meta.env.VITE_SUPABASE_KEY;`. Fuentes: `frontend/.env.production` (base real `https://zplcgetquwxybkrpmcvl.supabase.co`) y `frontend/.env.staging` (base desechable), **ambos trackeados en git** (`git ls-files frontend/.env.production` los devuelve). El comentario `lib/boot.js:87-88` fija el contrato: "Cada build lleva SOLO su propia base — producción no expone staging".
- **Formato de la clave:** `sb_publishable_…` — el formato nuevo de "publishable key" de Supabase (sucesor del anon-key JWT). **Público por diseño**: solo identifica el proyecto y otorga el rol `anon`; la autorización real la da el JWT de sesión del usuario emitido por GoTrue + RLS en Postgres. Que esté committeada es aceptable; lo que NUNCA debe aparecer es la `service_role`/secret key (no aparece: `grep -ri "service_role\|sb_secret" frontend/src` → 0 en cliente; solo en migraciones SQL de revocación).
- **Enforcement server-side (lo que protege de verdad):** directorio `supabase/migrations/` con **157 `CREATE POLICY`** (`grep -rhoi "create policy" supabase/migrations/*.sql | wc -l`; 150 en `20260616150834_remote_schema.sql`, 5 en `…seed_permisos_autocontenido.sql`, 2 en `…gasto_comments_hilo_observar.sql`), **78 `ENABLE ROW LEVEL SECURITY`** y **76 `SECURITY DEFINER`**. Endurecimiento explícito del rol anónimo: `20260621120000_revoke_anon_funciones_sensibles.sql` (`REVOKE EXECUTE ON FUNCTION public.asignar_cargo_a_miembro(text, text, text) FROM PUBLIC, anon;` etc.), `20260617144834_endurecimiento_anon_y_search_path.sql`, `20260616160154_revoke_funciones_internas.sql`, y hasta `20260621140000_revoke_service_role_funciones_sensibles.sql`. El cliente asume ese contrato: `modules/dal.js:249-251` — "Un externo NO puede leer la tabla contacts (RLS exige 'bd' E|L, que no tiene), así que BD_CONTACTOS llega vacío…".
- **Sesión en el navegador:** supabase-js v2 persiste el token de sesión en `localStorage` por defecto (clave `sb-<ref>-auth-token`); además la app guarda `takeos_auth_uid`, `takeos_auth_at`, `takeos_usuario_actual`, `takeos_usuario_uid` (limpiados en logout, `lib/boot.js:92-93`). Consecuencia estándar: cualquier XSS exitoso roba la sesión — la CSP estricta de §3 es la mitigación primaria.

---

## 6. Validación de entrada

**Primitivas** (en `lib/helpers.js`, re-exportadas a window en `main.js:43-44` sin lector runtime):

```js
export function escapeHtml(s) {
  if (s === null || s === undefined) return '';
  return String(s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
```
(`lib/helpers.js:7-13`) y

```js
export function safeUrl(u) {
```
(`lib/helpers.js:29-42`): strip de controles C0/C1 (`stripControlChars`, `helpers.js:17-25`), allowlist de esquemas `http`/`https`/`blob` + `data:image/*` únicamente, resto → `''`, y pasa el resultado por `escapeHtml`. Origen documentado: "pen-test MEDIA #6" (`helpers.js:27`).

**Call-sites:** `escapeHtml(` → **619** (`grep -rno "escapeHtml(" src --include="*.js" | wc -l`; incluye la definición y los `define`); además **21** aliases `const/var e = escapeHtml` (`grep -rn "const e = escapeHtml\|var e = escapeHtml" | wc -l`) cuyos usos `e(…)` NO están contados en los 619 — el número real de escapes es mayor. `safeUrl(` → **24** (`grep -rno "safeUrl(" | wc -l`), concentrados en atributos `src`/`href` (logos, fotos de locación, comprobantes).

**Sinks de HTML:** 224 líneas mencionan `innerHTML` (`grep -rn "innerHTML" src --include="*.js" | wc -l`), de las cuales **216 son asignaciones** (`grep -rnE "\.innerHTML\s*[+]?=" | wc -l`), **22** son limpiezas a `''` y **1** es lectura; + `insertAdjacentHTML` ×2, `outerHTML` ×2, `document.write` ×0 en documento principal (1 `doc.write` sobre el iframe de impresión, `plan-rodaje.js:1080`). Por archivo (grep -rc): `config.js` 48, `presupuesto-cotizacion.js` 32, `bd.js` 17, `gastos.js` 16, `lib/ui.js` 12, `plan-rodaje.js` 10, `kanban.js` 9, `espacio.js` 9, resto ≤8.
**Contrato implícito:** los templates escapan en el punto de interpolación (patrón `${escapeHtml(x)}` / alias `e(x)`); los args de eventos van por `accionHTML` que escapa el JSON (`lib/delegacion.js:30`: `a += ' data-args="' + escapeHtml(JSON.stringify(args)) + '"'`) y el dispatcher los recupera vía `dataset` sin re-parseo de JS (`delegacion.js:44-46`). Dos sinks **por contrato reciben HTML crudo** y delegan el escape al caller: `showModal({ title, body, … })` (`lib/ui.js:25-43`, interpola `${title}`/`${body}` directo en `root.innerHTML`) y `showToast({ kind, title, body, duration })` (`helpers.js:48-58`, `el.innerHTML` con title/body sin escapar) — ver Hallazgos.

---

## Hallazgos

1. **Gating de permisos muerto por selectores `[onclick*=]` huérfanos** — `lib/boot.js:293` (`document.querySelector('.cr-actions .btn-primary[onclick*="newProject"]')`) y `lib/boot.js:298` (`'.cr-actions [onclick*="openGlobalCFO"]'`). `index.html` tiene **0** atributos `onclick` (`grep -c onclick` → 0); los botones reales usan `data-accion="app.nuevoProyecto"` (`index.html:1390`) y `data-accion="app.cfo"` (`index.html:1386`). Ambos selectores devuelven `null` ⇒ el ocultamiento por `authNivel('crear_proyecto')`/CFO nunca se aplica: perfiles de solo-lectura ven los botones activos. Mitigado en servidor por RLS/REVOKE, pero la UI miente y la escritura fallará tarde.
2. **Trampa TDZ latente en `lib/state.js:54`** — `export let USUARIO_ACTUAL = ('USUARIO_ACTUAL' in window) ? USUARIO_ACTUAL : '';`. En la rama verdadera, el identificador `USUARIO_ACTUAL` resuelve al propio binding `let` en inicialización (no a `window.USUARIO_ACTUAL`) ⇒ `ReferenceError` por TDZ. Hoy nunca se dispara porque nada crea `window.USUARIO_ACTUAL` antes del eval (`grep -rn "window.USUARIO_ACTUAL"` → 0), pero es código imposible: la rama "preserva el valor previo" no puede funcionar jamás.
3. **CDNs sin SRI y versión flotante** — `integrity` aparece 0 veces en `index.html`; `index.html:1284` carga `@supabase/supabase-js@2` (major flotante: cada release entra sin revisión) y los loaders dinámicos `bd-excel.js:64,79` tampoco fijan `integrity`. Combinado con `script-src` que permite **todo** `cdn.jsdelivr.net` (espejo completo de npm) y `cdnjs.cloudflare.com`, la allowlist es un bypass de CSP conocido y la cadena de suministro queda sin verificación criptográfica.
4. **Doble carga de SheetJS** — `xlsx@0.18.5` se carga eager desde jsdelivr (`index.html:1282`) **y** lazy desde cdnjs (`bd-excel.js:64`, guardado por `if (window.XLSX)`). El eager convierte al lazy-loader en no-op y carga ~900 KB en todo arranque aunque no se use Excel; eliminarlo permitiría además sacar un origen menos… no — cdnjs seguiría; pero reduce peso y ambigüedad de procedencia.
5. **`showToast` inyecta HTML sin escapar y recibe `e.message` crudo** — sink en `helpers.js:55-58`; 13 call-sites pasan mensajes de error del servidor como `body` (p.ej. `bd-excel.js:265` `showToast({ kind: 'error', title: 'No se pudo exportar', body: e.message })`, `cargos.js:175`, `dal.js:83`, `config.js:385,412`). Los mensajes de PostgREST/GoTrue pueden reflejar fragmentos de input; con `script-src` estricta no ejecuta JS, pero permite inyección de marcado/estilo en el toast. Escapar por defecto dentro de `showToast` costaría una línea.
6. **Clickjacking estructuralmente no mitigable en el hosting actual** — `frame-ancestors` no aplica vía `<meta>` (`index.html:27-30`) y GitHub Pages no permite headers; no hay siquiera un frame-buster JS de respaldo. Riesgo aceptado implícitamente, sin registro de decisión más allá del comentario.
7. **Comentarios de censo desactualizados (window/ganchos)** — `state.js:157` "puente para src/modules/kanban.js" (kanban **importa** `PROJECTS`), `state.js:176` "puente para notificaciones.js", `dal.js:931` "puente para módulos", `dal.js:1850` "Lo invoca _setOrgActiva (boot.js) vía window" (hoy import en `boot.js:17,159`): los espejos ya no tienen lectores desnudos (verificado por script §1.b-D) y los comentarios señalan aristas que murieron en D4c. Un ingeniero nuevo re-preservaría bridges muertos por miedo.
8. **Asignaciones window duplicadas** — `window.STATE` en `state.js:226` **y** `main.js:48`; `window._clientUuid` en `modelo.js:424` **y** `presupuesto-cotizacion.js:4335`. Inofensivas (mismo referente) pero delatan que el guard anti-redefinición de `ganchos.js:19` no cubre el canal window.
9. **36 bridges de función y 18 espejos de datos sin ningún lector runtime** (§1.b grupos C/D) — superficie global mantenida solo como API de consola, sin marca que la distinga de los 9 bridges load-bearing (grupo B). Un barrido futuro no puede diferenciar "borrable" de "rompe-la-app" sin repetir el análisis de lectores desnudos; convendría el mismo tratamiento greppable que tienen los ganchos.
10. **Fuentes muertas** — `index.html:1274` carga Cormorant Garamond + Inter desde Google Fonts; ninguna aparece en `styles.css` ni en `src/` (greps → 0); la única familia real es Poppins vía `@import` en `styles.css:1`. Doble mecanismo de carga de fuentes (link + @import) y ~2 requests de CSS/woff2 inútiles por visita.
11. **`_ORG_EPOCA` y `__TAKEOS_USER` como estado window sin dueño en `state.js`** — ambos sobreviven fuera del sistema de dueños (`state.js`/`rates.js`) y de los ganchos: `_ORG_EPOCA` podría ser `let` local de `dal.js` (§2); `__TAKEOS_USER` duplica `USUARIO_ACTUAL` con escritores distintos (`setUsuarioActual` vs asignación directa) — doble fuente de verdad para la identidad mostrada.
12. **Iframes de impresión/preview sin `sandbox`** — `plan-rodaje.js:1075-1080` y `presupuesto-cotizacion.js:4089`: same-origin, privilegios completos, contenido construido por concatenación; hoy la CSP heredada bloquea inline-script dentro del iframe, pero no hay segunda barrera si la política se relaja algún día.