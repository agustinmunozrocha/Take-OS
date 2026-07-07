# Topología del repositorio, build y despliegue — TakeOS

Rama analizada: `etapa4-integracion` (HEAD `4c8067b`, 2026-07-03). Todo lo contado se contó con el comando indicado entre paréntesis.

---

## 1. Árbol completo del repo desde la raíz

```
/home/juandlc/Trabajo/Take-OS
├── .gitignore                 (3 líneas: .DS_Store, frontend/node_modules/, frontend/dist/)
├── .github/workflows/deploy.yml   (58 líneas — único workflow)
├── .claude/                   (NO trackeado: settings.json, settings.local.json — «?? .claude/» en git status)
├── docs/                      (19 archivos trackeados)
│   ├── CHANGELOG.md · CLAUDE.md · TakeOS_ADR_Backend_v1_10.md
│   ├── TakeOS_Arquitectura_y_Flujo_de_Trabajo_v1_6.md · TakeOS_PRD_V3_6.md
│   ├── TakeOS_Roadmap_Operativo_v1_8.md · TakeOS_Seguridad_OWASP_Top_10_2025_v1_3.md
│   ├── Marketing/Landing_Preliminar_Software_v3.html
│   ├── Planes/   (6 .md: HANDOFF_Code_PlanG…, PENDIENTES_Migracion_Vite, Plan_Macro_Frentes…, Plan_Modularizacion_Juan_v7, Plan_Modularizacion_Vite, RESUMEN_Sesion_Modularizacion)
│   └── mockups/  (4 .html + Handoff_Code_Integracion_Mockups.md)
├── frontend/                  (49 archivos trackeados; ver §2)
│   ├── index.html · package.json · package-lock.json · vite.config.js
│   ├── .env.production · .env.staging · .nvmrc · .gitkeep
│   ├── src/{main.js, styles.css, lib/ (14 .js), modules/ (25 .js)}
│   ├── dist/                  (gitignored; build local presente, ver §3)
│   └── node_modules/          (gitignored; 13 paquetes top-level)
└── supabase/                  (24 archivos trackeados)
    ├── config.toml (config CLI Supabase local, project_id="supabase", api.port=54321) · .gitignore
    ├── .temp/                 (gitignored: cli-latest, project-ref, rest-version, …)
    ├── catalogos_globales/    (README.md + seed.sql)
    ├── migrations/            (14 .sql, 20260616150834 → 20260629120000)
    └── queries/               (README.md + analisis/monitor_reversiones.sql; mantenimiento/, reportes/, Seeds/ solo con .gitkeep)
```

**No hay README.md, package.json ni index.html en la raíz** en esta rama (`ls -la` raíz: solo `.gitignore` como archivo). En `origin/main` (producción) la raíz SÍ tiene `index.html` — ver §4.

Tamaños (archivos trackeados por carpeta: `git ls-files | cut -d/ -f1 | sort | uniq -c`): **docs 19 · frontend 49 · .github 1 · supabase 24 · raíz 1 = 94 archivos trackeados**.

Líneas:
- `docs/` completo: **8.709 líneas** en 19 archivos (`wc -l docs/*.md docs/Planes/*.md docs/mockups/* docs/Marketing/*`). Mayores: `TakeOS_PRD_V3_6.md` 1.005, `mockup_creacion_productora.html` 1.145, `TakeOS_ADR_Backend_v1_10.md` 663.
- `supabase/` SQL: **16 archivos .sql, 9.349 líneas** (`find supabase -name '*.sql' -not -path '*/.temp/*' | wc -l` y `… -exec cat {} + | wc -l`). La migración dominante es `20260616150834_remote_schema.sql` (277.039 bytes, volcado del esquema remoto). Última migración: `20260629120000_archivar_bd_soft_delete.sql` (122 líneas).
- `frontend/src/`: **40 archivos .js, 25.327 líneas** (`find frontend/src -name '*.js' | wc -l`; `… -exec cat {} + | wc -l`) + `styles.css` 3.230 líneas + `index.html` 1.556 líneas (`wc -l`).

---

## 2. frontend/: src/, lista completa de .js, index.html

### 2.1 Inventario completo de .js por tamaño (`wc -l frontend/src/lib/*.js frontend/src/modules/*.js frontend/src/main.js | sort -rn`)

**modules/ (25 archivos, lógica de negocio):**

| líneas | archivo |
|---:|---|
| 4.480 | `frontend/src/modules/presupuesto-cotizacion.js` |
| 2.171 | `frontend/src/modules/config.js` |
| 1.899 | `frontend/src/modules/dal.js` |
| 1.695 | `frontend/src/modules/gastos.js` |
| 1.490 | `frontend/src/modules/plan-rodaje.js` |
| 1.195 | `frontend/src/modules/bd.js` |
| 925 | `frontend/src/modules/legal.js` |
| 909 | `frontend/src/modules/locaciones.js` |
| 759 | `frontend/src/modules/bd-excel.js` |
| 734 | `frontend/src/modules/notificaciones.js` |
| 655 | `frontend/src/modules/calculadoras.js` |
| 636 | `frontend/src/modules/persistencia-local.js` |
| 606 | `frontend/src/modules/perfil-onboarding.js` |
| 593 | `frontend/src/modules/info-proyecto.js` |
| 450 | `frontend/src/modules/espacio.js` |
| 450 | `frontend/src/modules/cargos.js` |
| 396 | `frontend/src/modules/admin.js` |
| 362 | `frontend/src/modules/crew.js` |
| 360 | `frontend/src/modules/kanban.js` |
| 338 | `frontend/src/modules/tareas.js` |
| 226 | `frontend/src/modules/rodajes.js` |
| 224 | `frontend/src/modules/documentos.js` |
| 215 | `frontend/src/modules/invitaciones.js` |
| 107 | `frontend/src/modules/plan-limites.js` |
| 93 | `frontend/src/modules/buscador.js` |

**lib/ (14 archivos, infraestructura):**

| líneas | archivo |
|---:|---|
| 802 | `frontend/src/lib/ui.js` |
| 737 | `frontend/src/lib/boot.js` |
| 531 | `frontend/src/lib/modelo.js` |
| 263 | `frontend/src/lib/calc.js` |
| 249 | `frontend/src/lib/nav.js` |
| 246 | `frontend/src/lib/state.js` |
| 93 | `frontend/src/lib/catalogos.js` |
| 82 | `frontend/src/lib/auth.js` |
| 70 | `frontend/src/lib/data.js` |
| 63 | `frontend/src/lib/helpers.js` |
| 60 | `frontend/src/lib/delegacion.js` |
| 54 | `frontend/src/lib/rates.js` |
| 34 | `frontend/src/lib/ganchos.js` |
| 25 | `frontend/src/lib/supabase.js` |

**Entrada:** `frontend/src/main.js` (50 líneas). Importa en orden fijo: 6 imports con nombre (`helpers`, `supabase`, `rates`, `state`) + 7 side-effect de lib (`modelo`, `data`, `auth`, `calc`, `ui`, `nav`, y `boot.js` como ÚLTIMA línea de import, `main.js:41`) + los 25 módulos (`main.js:16-40`). Invariante de orden documentado en `main.js:15`: «nav.js antes de gastos.js: goWire lee window.MODULES en eval». El puente residual a window queda en `main.js:43-48`:

```js
window.escapeHtml = escapeHtml;
window.safeUrl = safeUrl;
window.showToast = showToast;
window.supabaseInit = supabaseInit; // al llamarse, setea window.sb
window.dalBootTaxRates = dalBootTaxRates;
window.STATE = STATE; // mismo objeto compartido (estado global)
```

Ocurrencias textuales de `window.` restantes en src/: **199** (`grep -rno 'window\.' frontend/src --include='*.js' | wc -l`) — el «962→73» del commit `5e1d621` refiere a propiedades distintas, no a ocurrencias.

Firmas reales de los dos contratos de infraestructura del desacople:

`frontend/src/lib/ganchos.js:18,23,31`:
```js
export function define(nombre, fn) {
export function gancho(nombre) {
export function valor(nombre) {
```
Invariantes declarados en su cabecera (`ganchos.js:12-14`): «Todos los define() corren al EVAL del productor (antes de DOMContentLoaded); toda invocación es runtime post-arranque — nunca hay carrera. Un gancho sin definir grita en consola con su nombre».

`frontend/src/lib/delegacion.js:16,24`:
```js
export function registrarAcciones(ns, mapa) {
export function accionHTML(accion) {
```
Contrato de acción (`delegacion.js:10-11`): «Firma de toda acción: (args, el, ev)». Un listener por tipo a nivel `document` para `['click','input','change','keydown','dblclick','mousedown','paste','submit','dragover','dragleave','drop']` en burbuja y `['focus','blur']` en captura (`delegacion.js:55-60`).

### 2.2 index.html (1.556 líneas — `wc -l`)

Anatomía por rangos de línea:
- **1–4**: doctype, `<html lang="es">`, charset.
- **5–35**: comentario de seguridad + la meta CSP (línea 35).
- **39–1269**: **comentario changelog embebido de ~1.230 líneas** (historial V5→V8.6.0 dentro de un solo `<!-- -->`): el 79% del archivo es comentario.
- **1271–1275**: links de fuentes y CSS.
- **1278–1556**: `<body>` — todo el DOM estático son ~279 líneas.

**Meta CSP VERBATIM** (`frontend/index.html:35`):
```html
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: blob: https:; connect-src 'self' https://*.supabase.co wss://*.supabase.co; frame-src 'self' blob:; object-src 'none'; base-uri 'self'" />
```
Notas del propio comentario (líneas 9-33): `script-src` sin `'unsafe-inline'` desde D3; `style-src` retiene `'unsafe-inline'` («miles de style= — proyecto aparte»); `frame-ancestors` NO aplica vía `<meta>` y debería ir como header del hosting.

**Tags `<script>` y `<link>` exactos:**
```html
1271: <link rel="preconnect" href="https://fonts.googleapis.com">
1272: <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
1273: <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@400;500;600;700&family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
1275: <link rel="stylesheet" href="/src/styles.css">
1282: <script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
1284: <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
1287: <script type="module" src="/src/main.js"></script>
```

**DOM estático** (ids únicos: 37 — `grep -oE 'id="[^"]+"' | sort -u | wc -l`):
- `#bootVeil` (1279): cortina anti-flash gobernada por `src/lib/boot.js`.
- `header.topbar` (1294–1355): brand (`#brandLogo/#brandSub/#brandVer`), breadcrumb, switcher de espacio (`#eswWrap/#eswMenu`), búsqueda global (`#globalSearch` + `#gsearchResults`), `#adminBadge`, `#undoBtn`, `#loadFileInput`, campana (`#notifBtn/#notifBadge/#notifPanel/#notifList`), `#userAvatar/#userName`, `#logoutBtn`.
- Helpers UI (1360–1362): `#toastContainer`, `#modalRoot`, `#confettiCanvas`. **Cero modales estáticos** (`grep -c 'class="modal'` → 0); todo modal se monta dinámicamente en `#modalRoot`.
- `section#controlRoomView` (1367–1436): header con acciones (`app.importProyectoBtn`, `app.papelera`, `app.cfo`, `app.nuevoProyecto`), 3 metric-cards (`#metric-active`, `#metric-closed-month`, `#metric-alerts`), toolbar de filtros (`data-filter`/`data-view`), `#crTareasPanel`, `#kanbanContainer`.
- `section#projectView.hidden` (1441–1535): `aside.sidebar` con `#sidebarProject` (render JS) + **4 sidebar-section / 16 sidebar-item** con `data-module="…" data-accion="app.modulo"` (info-proyecto, bd-personas, presupuesto, cotizacion, crew, cargos, documentos | rodajes, locaciones, hoja-llamado, plan-rodaje, legal | correos, gastos | entregables SOON, reporte-cierre V6); `main#moduleMain` (1531) como contenedor de módulo activo.
- `section#bdGlobalView.hidden` (1544–1548) con `main#bdGlobalMain` — contenedor dedicado para no duplicar `#moduleMain` (bug documentado en 1537–1543).

Wiring estático: **32 atributos `data-accion`** (`grep -c 'data-accion'`), **0 handlers inline `on*=`** (`grep -cE ' on[a-z]+="'` → 0), 12 `style=` inline (`grep -c 'style="'`). Comentario de cierre (`index.html:1552`): «El `<script>` clásico del monolito quedó VACÍO en la Etapa C6».

---

## 3. Sistema de build

**`frontend/package.json` completo** (14 líneas):
```json
{
  "name": "takeos-frontend",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --mode staging",
    "build": "vite build",
    "build:staging": "vite build --mode staging",
    "preview": "vite preview"
  },
  "devDependencies": {
    "vite": "^7.0.0"
  }
}
```
**Cero dependencias de runtime en npm** — todo el runtime externo entra por CDN (§5). Lockfile: 64 entradas de paquete, todas transitivas de Vite (vite 7.3.5, rollup 4.62.0, esbuild 0.27.7 — leído de `package-lock.json` con python3/json). `.nvmrc` = `20`.

**`frontend/vite.config.js` completo** (10 líneas):
```js
import { defineConfig } from 'vite'

// base: './' = rutas relativas. El mismo build funciona en producción
// (/Take-OS/) y en staging (/takeos-staging/) sin cambios. Mata el 404.
export default defineConfig({
  base: './',
  build: {
    outDir: 'dist',
  },
})
```
Configuración implícita: entrada = `frontend/index.html`, sin plugins, sin alias, sin code-splitting manual → un solo chunk JS + un CSS.

**Entornos por archivos .env comiteados** (`git ls-files frontend/.env.*` los confirma trackeados):
- `.env.production`: `VITE_SUPABASE_URL=https://zplcgetquwxybkrpmcvl.supabase.co` + `VITE_SUPABASE_KEY=sb_publishable_…` (base real; se inyecta solo en `vite build`).
- `.env.staging`: `VITE_SUPABASE_URL=https://jovroabtwysliryppthh.supabase.co` + key publishable (dev local y `build:staging`).

Consumo en `frontend/src/lib/supabase.js:11-12`:
```js
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_KEY = import.meta.env.VITE_SUPABASE_KEY;
```
con `export function supabaseInit()` (`supabase.js:17`) que crea el cliente vía el global CDN `supabase.createClient(SUPABASE_URL, SUPABASE_KEY)` (`supabase.js:21`) y lo espeja en `window.sb`. Invariante (`supabase.js:16`): `if (!('sb' in window)) window.sb = null;` — la propiedad existe desde el eval del módulo para que los guards `if (!sb)` del DAL nunca lancen ReferenceError.

**dist/ (gitignored, presente localmente; build del 2026-07-03 19:24, `ls -la`):**
- `dist/index.html` — 1.556 líneas, 111.463 bytes (fuente: 111.409 bytes; Vite solo reescribe los tags, no poda comentarios). Transformación observable: `dist/index.html:1276-1277`:
  ```html
  <script type="module" crossorigin src="./assets/index-DURjYUNe.js"></script>
  <link rel="stylesheet" crossorigin href="./assets/index-BXnPvULk.css">
  ```
  Los scripts CDN (xlsx, supabase-js) pasan intactos.
- `dist/assets/index-DURjYUNe.js` — **1.003.237 bytes** (todo src/ en un chunk).
- `dist/assets/index-BXnPvULk.css` — **110.196 bytes**.
- Este build local es de **modo producción**: la URL `zplcgetquwxybkrpmcvl` aparece 1 vez en el chunk y `jovroabtwysliryppthh` 0 veces (`grep -o … | sort | uniq -c`).

---

## 4. Despliegue y git

**Remotos** (`git remote -v`):
```
origin   https://github.com/agustinmunozrocha/Take-OS.git          (producción)
staging  https://github.com/agustinmunozrocha/takeos-staging.git   (staging)
```

**Ramas locales** (`git branch`): 39 — `main`, 4 ramas de etapa (`etapa1-lib`, `etapa2-integracion`, `etapa3-integracion`, `etapa4-integracion`*actual*) y 34 ramas `mod-*` (una por módulo extraído: `mod-bd`, `mod-c1..c6`, `mod-config`, `mod-cotizacion`, `mod-d0`, `mod-d1a..d1e`, `mod-d2a..d2f`, `mod-d3a`, `mod-d4a..d4c`, `mod-dal`, `mod-data`, `mod-gastos`, `mod-kanban`, `mod-legal`, `mod-locaciones`, `mod-notificaciones`, `mod-persistencia`, `mod-plan-rodaje`). Tags: `candidato-lote1`, `pre-lote1-prod` (`git tag`).

**Workflow único** `.github/workflows/deploy.yml` (58 líneas): «Deploy a GitHub Pages». Dispara en `push` a `main` + `workflow_dispatch`; `concurrency: group: pages, cancel-in-progress: true`; job `build` (ubuntu-latest, `working-directory: frontend`, setup-node 20 con cache npm sobre `frontend/package-lock.json`, `npm ci`) y elige el modo **por identidad del repositorio**:
```yaml
if [ "${{ github.repository }}" = "agustinmunozrocha/takeos-staging" ]; then
  npm run build:staging
else
  npm run build
fi
```
luego `actions/upload-pages-artifact@v3` con `path: frontend/dist` y job `deploy` con `actions/deploy-pages@v4` (environment `github-pages`).

**Estado real de los dos remotos** (verificado, no según docs):
- `staging/main` HEAD = `4c8067b` (2026-07-03) — **idéntico al HEAD local de `etapa4-integracion`** (`git log -1 staging/main`). Staging ya corre el frontend modular con Vite: el flujo de publicación a staging es *push de la rama de etapa al `main` del repo espejo takeos-staging*, donde `deploy.yml` construye con `build:staging`.
- `origin/main` HEAD = `fa008d5` (2026-06-30, «Merge fix/cfo-persistir-validacion-gastos»). Su árbol (`git ls-tree origin/main`) es `[.gitignore, docs, frontend, index.html, supabase]`: **producción todavía es el monolito `index.html` de 28.649 líneas en la raíz** (`git show origin/main:index.html | wc -l`), con `frontend/` conteniendo solo `.gitkeep` (`git ls-tree -r origin/main | grep frontend`) y **sin ningún workflow** (`git ls-tree -r origin/main | grep .github` → vacío): GitHub Pages en producción publica directo desde la rama, sin build. `etapa4-integracion` está **189 commits por delante** de `main` local (`git log --oneline main..etapa4-integracion | wc -l`); el corte de producción a la build de Vite está pendiente.

Flujo de BD: según `docs/CLAUDE.md:70`, cambios de BD = migración en `supabase/migrations/` → PR con preview branch → merge a `main` → Branching de Supabase aplica al mergear («merge = deploy»); prohibido `supabase db push` manual a producción.

---

## 5. Dependencias externas de runtime (CDN)

| Librería | Origen y versión | Carga | Global | Uso en src/ |
|---|---|---|---|---|
| SheetJS (xlsx) | `cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js` (`index.html:1282`) — pin exacto | `<script>` bloqueante siempre | `XLSX` | 31 ocurrencias de `XLSX.` en 2 archivos: `modules/bd-excel.js` y `modules/gastos.js` (`grep -rn 'XLSX\.' | wc -l`). Import/export .xlsx de la BD y export Chipax de gastos |
| SheetJS (xlsx, 2ª vía) | `cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js` (`bd-excel.js:64`) | bajo demanda vía `function ensureXLSX()` (`bd-excel.js:60`), Promise que resuelve `window.XLSX` | `XLSX` | fallback/lazy del mismo paquete |
| ExcelJS | `cdnjs.cloudflare.com/ajax/libs/exceljs/4.4.0/exceljs.min.js` (`bd-excel.js:79`) | bajo demanda vía `function ensureExcelJS()` (`bd-excel.js:75`), expuesto como gancho (`define('ensureExcelJS', ensureExcelJS)`, `bd-excel.js:754`) | `ExcelJS` | solo exports con estilo del Presupuesto: `presupuesto-cotizacion.js:1820` `try { ExcelJSlib = await gancho('ensureExcelJS')(); }` |
| supabase-js | `cdn.jsdelivr.net/npm/@supabase/supabase-js@2` (`index.html:1284`) — **rango flotante @2, sin pin** | `<script>` bloqueante siempre | `supabase` | un único punto de consumo: `lib/supabase.js:21` `sb = supabase.createClient(...)`; el resto usa `sb.*` |
| Google Fonts | `fonts.googleapis.com` (CSS) + `fonts.gstatic.com` (woff2), `index.html:1271-1273` | `<link>` | — | tipografías Cormorant Garamond + Inter |

Los cuatro orígenes coinciden 1:1 con la CSP (`script-src` jsdelivr+cdnjs, `style-src` googleapis, `font-src` gstatic, `connect-src` *.supabase.co).

---

## Hallazgos

1. **Deriva producción/staging de 189 commits y dos topologías incompatibles.** `origin/main` sirve el monolito raíz de 28.649 líneas sin workflow ni CSP modular; todo el desacople (CSP estricta incluida) solo existe en `takeos-staging` y ramas locales. Mientras no se haga el corte, cualquier hotfix de producción se hace sobre un árbol radicalmente distinto al de desarrollo (`git ls-tree origin/main` vs rama actual).
2. **`docs/CLAUDE.md` desactualizado y auto-inconsistente.** Dice «Vive en la raíz del proyecto» pero está en `docs/CLAUDE.md`; su §Stack (línea 19) describe la modularización como «Etapa 2 pendiente, ~88% del trabajo por hacer», cuando la rama actual tiene las etapas 1–4 completas (40 módulos, 25.327 líneas en src/). Y `docs/CLAUDE.md:84` afirma «Base: 7 migraciones» cuando hay 14 en `supabase/migrations/` (`ls | wc -l`).
3. **~1.230 líneas de changelog embebido como comentario en `index.html` (líneas 39–1269) viajan al cliente en cada carga**: `dist/index.html` pesa 111.463 bytes de los cuales el DOM útil son ~280 líneas; Vite no poda comentarios HTML. Peso muerto de ~100 KB pre-gzip por visita e historial interno (nombres, razón social, decisiones) expuesto públicamente.
4. **supabase-js sin pin de versión ni SRI**: `@supabase/supabase-js@2` (`index.html:1284`) es un rango flotante — un release del CDN puede cambiar el runtime de producción sin commit. Ninguno de los `<script>` CDN (tampoco xlsx pineado) lleva `integrity=`; la CSP restringe origen, no contenido.
5. **Doble vía de carga de xlsx 0.18.5**: se carga SIEMPRE bloqueante desde jsdelivr (`index.html:1282`) y además `ensureXLSX()` (`bd-excel.js:60-69`) lo re-carga bajo demanda desde cdnjs si `window.XLSX` falta. Redundante en el caso normal; y si el objetivo era lazy-load, el `<script>` estático lo anula.
6. **`dist/` local contiene un build de PRODUCCIÓN generado desde la rama de staging** (URL `zplcgetquwxybkrpmcvl` horneada; `grep -o … dist/assets/index-DURjYUNe.js`, 2026-07-03 19:24, posterior al HEAD). Está gitignored, pero es un artefacto apuntando a la base real construido desde código no mergeado a producción — riesgo si alguien lo publica a mano.
7. **`frame-ancestors` ausente de facto**: el propio comentario (`index.html:27-30`) reconoce que vía `<meta>` el navegador lo ignora y que debe ir como header del hosting — GitHub Pages no permite headers custom, así que la mitigación anti-clickjacking queda sin implementar en este hosting.
8. **Código muerto residual del apagado de espejos**: `frontend/src/lib/rates.js:19-23` conserva `function _espejo() {` con cuerpo vacío (solo líneas en blanco) y su llamada `_espejo();` — resto de D4c sin cosechar.
9. **Comentarios con cifras fósiles**: `index.html:1552` dice «main.js importa 20 módulos + 10 libs» pero `main.js` importa 25 módulos y 11 entradas de lib (contado sobre `main.js:6-41`).
10. **Selección de entorno de build acoplada al nombre del repo** (`deploy.yml`: `if github.repository == "agustinmunozrocha/takeos-staging"`): un fork/rename rompe silenciosamente la selección y construiría staging con la base de producción; el contrato entorno↔repo no está validado en ningún otro punto.
11. **Carpetas placeholder**: `supabase/queries/{mantenimiento,reportes,Seeds}` solo contienen `.gitkeep`; la única query real es `analisis/monitor_reversiones.sql`.
12. **Claves Supabase comiteadas** en `frontend/.env.production` y `.env.staging` (trackeadas por git). Son `sb_publishable_*` (públicas por diseño, defendidas por RLS), pero el patrón normaliza comitear `.env` — el `.gitignore` de `supabase/` sí excluye `.env.*.local`, el de la raíz no dice nada de `frontend/.env*`.