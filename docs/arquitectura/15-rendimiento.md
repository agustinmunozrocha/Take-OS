# Perfil de rendimiento — Rizora `frontend/` (commit `4c8067b`, rama `etapa4-integracion`)

Metodología: solo lectura sobre `/home/juandlc/Trabajo/Take-OS/frontend`; todas las cifras medidas con el comando indicado entre paréntesis. Los pesos de CDN se descargaron con `python3 urllib` y se comprimieron con `gzip.compress(nivel 9)` como proxy del transfer real (jsdelivr sirve brotli, que sería algo menor). Las únicas cifras estimadas (no medibles sin runtime) están marcadas **[estimación]**.

---

## 1. Presupuesto de carga (arranque frío de producción)

### 1.1 Chunk único confirmado

`frontend/vite.config.js` completo (9 líneas, `cat`):

```js
export default defineConfig({
  base: './',
  build: {
    outDir: 'dist',
  },
})
```

- **No hay `build.rollupOptions.output.manualChunks`** ni ninguna otra directiva de splitting.
- **Cero `import()` dinámicos** en todo `src/` (`grep -rn "import(" src/ --include="*.js" | wc -l` → **0**).
- `frontend/src/main.js:6-41` importa **eagerly los 25 módulos de `src/modules/` y 14 libs de `src/lib/`** — todo entra al chunk único `dist/assets/index-DURjYUNe.js`.
- El único lazy-loading real de la app es `ensureXLSX()` / `ensureExcelJS()` en `frontend/src/modules/bd-excel.js:60-84` (inyección de `<script>` bajo demanda desde cdnjs).

### 1.2 Tabla de pesos medidos

(raw: `wc -c`; gzip: `gzip -9 -c | wc -c` o `gzip.compress(...,9)`; CDN: descarga real con `urllib.request`)

| Recurso | Origen | raw (B) | gzip (B) |
|---|---|---:|---:|
| `dist/assets/index-DURjYUNe.js` | self | 1.003.237 | 287.720 |
| `xlsx.full.min.js@0.18.5` (eager, `index.html:1282`) | cdn.jsdelivr.net | 881.727 | 315.688 |
| `@supabase/supabase-js@2` (eager, `index.html:1284`) | cdn.jsdelivr.net | 206.178 | 52.148 |
| `dist/index.html` | self | 111.463 | 32.861 |
| `dist/assets/index-BXnPvULk.css` | self | 110.196 | 18.673 |
| Google Fonts CSS · Cormorant+Inter (`index.html:1273`) | fonts.googleapis.com | 20.419 | 941 |
| Google Fonts CSS · Poppins (`styles.css:1`, sobrevive al build: el CSS de dist **empieza** con `@import"https://fonts.googleapis.com/css2?family=Poppins..."`) | fonts.googleapis.com | 8.403 | 623 |
| Poppins woff2, subset latin × 7 caras (medidos uno a uno) | fonts.gstatic.com | 55.824 | 55.824 (ya comprimido) |
| **TOTAL** | | **2.397.447 B ≈ 2,29 MiB** | **764.478 B ≈ 747 KiB** |

≈14 requests antes del primer dato de Supabase (1 html + 2 scripts CDN + 1 js + 1 css + 2 css de fonts + 7 woff2).

Notas de medición:
- `dist/index.html` es **83,9 % comentario**: 93.485 de 111.409 bytes en 22 bloques `<!-- -->` (medido con `python3 re.findall(r'<!--.*?-->')`). Vite no los eliminó: dist conserva los 22 bloques.
- Las fuentes Cormorant Garamond + Inter de `index.html:1273` están **muertas**: `grep -rn "font-family[^;]*Inter\|font-family[^;]*Cormorant" index.html src/` → **0 resultados**. La única familia usada es Poppins (`src/styles.css:10`: `--font-sans: 'Poppins', ...`). El navegador descarga igualmente su CSS (20.419 B, render-blocking) aunque no baje los woff2 (unicode-range + fuente jamás pintada).
- **Bloqueo de parser**: los dos `<script src>` de CDN (`index.html:1282,1284`) son scripts clásicos **sin `defer`/`async`** colocados al inicio del `<body>` (línea 1282, antes de las ~270 líneas de markup de la app): el HTML de toda la UI espera la descarga+parse de ~1,09 MB raw (368 KB gz) de terceros.
- **Cadena serial de fuentes**: html → `index-BXnPvULk.css` (18,7 KB gz) → `@import` fonts.googleapis (línea 1 del CSS bundleado) → woff2. Tres saltos de red encadenados en el critical path del texto (con `display=swap` es FOUT, no bloqueo).

### 1.3 Las 3 reducciones de mayor palanca

1. **Retirar el `<script>` eager de xlsx (`index.html:1282`)**: −315.688 B gz = **41,3 % del transfer total**, y desbloquea el parser del body. La infraestructura ya existe: `ensureXLSX()` (`bd-excel.js:60`) hace lazy-load idempotente (`if (window.XLSX) return resolve(window.XLSX);`). Los únicos consumidores que usan `XLSX` global sin pasar por `ensureXLSX` son dos exports de `gastos.js:1215-1218` y `gastos.js:1305-1308` (`grep -rn "XLSX\." src/` → solo bd-excel.js ×19 y gastos.js ×12). Migrar esos 2 callsites y borrar la etiqueta.
2. **Strip de comentarios de `index.html`**: 111.463 → 17.978 B raw (−93.485); gzip 32.861 → **4.283 B** (−87 %, medido con `gzip.compress` sobre el HTML sin `<!-- -->`). Es un cambio de build (plugin de Vite o minify HTML), no de código.
3. **Fuentes**: borrar el `<link>` muerto de Cormorant+Inter (`index.html:1273`, −20.419 B raw + 1 request render-blocking + preconnects 1271-1272 que solo sirven a ese request) y reemplazar el `@import` de Poppins (`src/styles.css:1`) por self-host + `<link rel=preload>` de los 7 woff2 latin (55.824 B totales): elimina 2 RTTs seriales del critical path. (Bonus no contado en el top-3: fijar la versión de `@supabase/supabase-js@2` — el alias sin versión rompe el cacheo largo del CDN y hace el peso no reproducible entre deploys.)

Aun con las tres palancas, el chunk propio (287,7 KB gz / 1.003.237 raw) queda como el mayor ítem self-hosted; el split natural es por módulo (`presupuesto-cotizacion.js` 272.167 B fuente, `config.js` 166.206 B, `gastos.js` 127.231 B, `plan-rodaje.js` 117.903 B — `wc -c` por archivo), pero exige romper el import eager de `main.js:16-41`.

---

## 2. Patrones de render

### 2.1 Contrato base

Dispatcher `frontend/src/lib/nav.js:200`:

```js
export function renderModule(key) {
```

Reconstruye `main.innerHTML` (header + `<div class="module-content" id="moduleContent">`) y llama `m.render()`. **Invariante del sistema**: cada módulo pinta serializando HTML a string y asignando `innerHTML` de `#moduleContent` (12 módulos escriben `getElementById('moduleContent')`, `grep -rl`); 224 asignaciones `innerHTML` en `src/` (`grep -rn "innerHTML" src --include="*.js" | wc -l`). No hay ningún vDOM/diffing: la granularidad del update la decide cada módulo a mano.

### 2.2 Clasificación por estrategia (callsites contados con `grep -c "renderX()"`)

**A. Re-render total del módulo por mutación** (cada setter reconstruye `#moduleContent` entero):

| Módulo | Render total | Callsites | Ejemplo de setter |
|---|---|---:|---|
| `plan-rodaje.js` | `function renderPlanRodaje() {` (:232) | **28** | `:477 function prSetDur(id, value) { ... markDirty(); renderPlanRodaje(); }` |
| `locaciones.js` | `export function renderLocaciones() {` (:176) | **18** | `:75 function locSetSub(s) { _locState().sub = s; renderLocaciones(); }` |
| `gastos.js` | `function renderGastos() {` (:143) | **13** | `:786 d.movimientos.push(m); markDirty(); closeModal(); renderGastos();` |
| `legal.js` | `export function renderLegal() {` (:217) | **11** | `:131 function legalSetFiltro(k, v) { _legalState()[k] = v; renderLegal(); }` |
| `cargos.js` ×8, `documentos.js` ×7, `info-proyecto.js` ×6, `kanban.js` ×4, `rodajes.js` ×4, `crew.js` ×3 | ídem | | |

`renderPlanRodaje()` (:246) concatena 4 secciones en un solo assignment: `content.innerHTML = `${prSwitcherHTML(...)}${prHeaderHTML(...)}${prTableHTML(...)}${prBancoHTML(...)}``. Mitigante: los campos de fila del plan van con `{ on: 'change' }` (`plan-rodaje.js:316,339,344,354,391`), o sea el rebuild es **por commit de campo**, no por keystroke.

**B. Re-render parcial de contenedor por keystroke, sin debounce**:
- `bd.js:1133` — `buscar: function (a, el) { STATE.ui.bdSearch = el.value; renderBDListByTab(); },` enganchado con `data-on="input"` (`bd.js:79`). `renderBDPersonList()` (:617) refiltra y re-serializa **toda** la lista: `rowsEl.innerHTML = filtrados.map(nombre => renderPersonRow(nombre)).join('');` (:634). Costo por keystroke = O(N contactos) en filtro + construcción de string + parse DOM de la lista completa. El input vive fuera de `#personRows`, así que el foco sobrevive.
- `gastos.js:262` — `function goRegFilter(v) { GO_REG_FILTER = v || ''; const tb = document.getElementById('goRegTbody'); if (tb && STATE.currentProject) tb.innerHTML = goRegRows(STATE.currentProject); }`: swap de tbody, sin debounce, por keystroke.
- Excepción con debounce: `legal.js:891` — `q: function (a, el) { clearTimeout(_lglQT); _lglQT = setTimeout(function () { legalSetFiltro('q', el.value); }, 250); },` — pero al disparar hace `renderLegal()` **completo**, que reconstruye el propio `<input>` de búsqueda (`legal.js:248`) ⇒ pérdida de foco tras cada pausa de 250 ms (no hay `focus()` de restauración en ese camino; los únicos `focus()` de legal.js:415,423 son del editor de plantillas).

**C. Patch quirúrgico (solo presupuesto)**:
`frontend/src/modules/presupuesto-cotizacion.js:1203`:

```js
export function afterRowChange(sectionKey, dept, idx) {
```

(comentario del propio archivo, :1200-1202: *"CORE DEL BUG FIX: en lugar de renderPresupuesto(), hacemos updates granulares al DOM. Esto preserva el estado de inputs, scroll, foco y secciones colapsadas."*). Localiza `tr[data-row-idx]` y toca celdas puntuales (`[data-cost-cotizado]`, `[data-delta-inline]`, `[data-costo-real]`, `[data-he-cell]`). `renderPresupuesto()` completo solo tiene **4** callsites (`grep -c`). Es el único módulo con esta disciplina.

Pero el patch quirúrgico **no es barato en cómputo**: el final de `afterRowChange` (:1301-1312) ejecuta `recalcSubdeptTotals(dept)` + `recalcDeptSummary(sectionKey)` + `recalcKPIs()` + `recalcAlerts()` + `renderHeadcountPanel()`; `recalcKPIs()` (:2316) es `renderSummaryFin()`, y `calcSummaryFin(project)` (:1483) arranca con `gancho('_syncGastosCostoReal')(project)` (:1484). Y la acción `pre.rowName` (:4448-4452) corre `updateRowField(...) ; afterRowChange(...)` **en el evento `input`** (binding `{ on: 'focus input blur change' }`, :768) ⇒ **por cada keystroke en la celda de nombre se re-escanea el presupuesto completo + todos los movimientos de gastos** (ver 2.3), aunque el DOM tocado sea mínimo.

### 2.3 Hot-paths cuadráticos documentados

Firmas reales:

```js
// gastos.js:95
function goPresById(project, id) { return goData(project).presupuestos.find(p => p.id === id) || null; }
// gastos.js:99
function goLineaOf(project, m) { const e = goPresById(project, m.pres); return e ? e.linea : 'Otros'; }
// gastos.js:564
function goLineaRealGastado(project, lineName) {
  const ln = _normLinea(lineName); if (!ln) return 0;
  return goMovs(project).filter(m => _normLinea(goLineaOf(project, m)) === ln).reduce((s, m) => s + (m.monto || 0), 0);
}
```

1. **Render de la sección "Gastos" del presupuesto** — `renderRoleRow(sectionKey, dept, item, idx, showReal)` (:679), invocado por fila desde `renderSimpleSection` (:673: `${_order.map(idx => renderRoleRow(...)).join('')}`), evalúa en :740-742:
   ```js
   const _gastosDerivado = _esGastosSec && (typeof goLineaTieneCaja === 'function')
     && gancho('goLineaTieneCaja')(STATE.currentProject, item.item)
     && gancho('goLineaRealGastado')(STATE.currentProject, item.item) > 0;
   ```
   `goLineaRealGastado` recorre **todos** los movimientos, y por cada movimiento `goLineaOf` hace un `.find` sobre **todos** los presupuestos ⇒ **O(F_gastos × M × P)** por render de la sección. Con la plantilla por defecto son 7 filas de gastos (`DEFAULT_GASTOS`: 7 ítems, contado en `src/lib/catalogos.js`), pero F, M y P crecen con el proyecto.
2. **`_syncGastosCostoReal(project)`** (`gastos.js:543`): `d.movimientos.forEach(m => { const k = _normLinea(goLineaOf(project, m)); ... })` ⇒ **O(M × P)** por invocación. Invocadores: `calcProjectTotals` (`src/lib/calc.js:57-58`), `calcSummaryFin` (`presupuesto-cotizacion.js:1484`) y `renderSimpleSection` (:586). Vía `pre.rowName` (input) → `afterRowChange` → `recalcKPIs` → `renderSummaryFin` → `calcSummaryFin`, este O(M×P) **corre por keystroke** al tipear un nombre de fila.
3. **Peor caso de la familia A [estimación]**: el renderer de fila de plan-rodaje ocupa 5.534 B de fuente (líneas 330-376, `sed | wc -c`) y el de presupuesto 12.886 B (líneas 679-855); un plan de rodaje de ~60 filas implica reconstruir y re-parsear del orden de decenas-a-cientos de KB de HTML **por cada commit de campo** (`change`), destruyendo y recreando todos los nodos del módulo (imágenes base64 de las filas incluidas, re-decodificadas por el parser). En `bd.js` el equivalente ocurre por keystroke sobre la lista completa de personas.

### 2.4 Costo oculto por mutación (transversal)

`persistencia-local.js:506`:

```js
export function markDirty() {
```

hace, en cada mutación de cualquier módulo: `recordUndoPoint()` (:529) que ejecuta `JSON.stringify(p)` **del proyecto completo** (:538: `UNDO_BASELINE = { id: p.id, snap: JSON.stringify(p) };`), `scheduleAutosave()` (2 s de debounce → `autosaveNow()` :488-495: `JSON.stringify(buildSaveObject())` = **todo el OS**: todos los proyectos + las 5 BDs, a localStorage), y `dalTouchProyecto(project)` (`dal.js:1865`, flush a Supabase a 1,5 s). Es decir: **cada `markDirty()` serializa el proyecto entero de forma síncrona**, aun cuando el cambio fue un carácter.

---

## 3. Límites de datos

### 3.1 Estructura de almacenamiento local

Claves dominantes (constantes en `persistencia-local.js`): `LS_KEY = 'takeos_autosave_v1'` (:44) y `SNAP_KEY = 'takeos_snapshots'` (:253, `SNAP_MAX = 5` :254). Ambas guardan el **OS completo** (`buildSaveObject()` :58-80: `projects + trash + empresaPerfil + bdContactos + bdEmpresasById + bdLoc + bdLegal + bdLegalTpl` **más tres proyecciones legacy duplicadas**: `bdPersonas`, `bdEmpresas`, `bdTalentos` — :75-79, "se siguen escribiendo" para clientes V7.2.x). `pushSnapshot` (:270) mete `json: JSON.stringify(buildSaveObject())` en un array FIFO de hasta 5.

**Aritmética de cuota** — si S = bytes de `JSON.stringify(buildSaveObject())`, el peor caso local es `S (autosave) + 5·S (snapshots) = 6·S`. Con cuota de 5 MB (Firefox/Safari) el sistema deja de escribir cuando **S > ~0,85 MB**; con 10 MB (Chrome, que además cuenta unidades UTF-16) cuando **S > ~1,7 MB**. El fallo es un `QuotaExceededError` capturado en :492-493 (autosave) y :268 (snapshots): un toast **una sola vez por sesión** (`_persisAvisarFallo`, :480-487) y a partir de ahí el respaldo offline queda congelado en silencio (la nube sigue).

### 3.2 Qué infla S: fotos base64

- Plan de rodaje: `function prCompressImage(file, maxPx, quality)` (`plan-rodaje.js:218`) → canvas 1100 px, `toDataURL('image/jpeg', 0.72)`; hasta 6 imágenes por fila y por campo (`arr.length < 6`, :314). Estas dataURLs viven **dentro de `project.data`** ⇒ entran a autosave, snapshots, undo y al payload de Supabase.
- Locaciones: `locAddFotos` (`locaciones.js:388`) comprime a 1280 px q0.6 y sube a Supabase Storage; **solo si Storage falla** cae al modo local `l.fotos.push({ url })` (:396-397) — ese fallback sí pesa en localStorage vía `bdLoc`.
- Cotas medidas con JPEGs sintéticos (PIL 12.1.1; gradiente = cota inferior, ruido = superior; base64 = ×4/3): 1100 px q0.72 → **32.632 B a 620.112 B** base64; 1280 px q0.60 → **27.872 B a 692.752 B** base64. Una foto real típica cae en ~100-250 KB base64 **[estimación dentro de las cotas medidas]** ⇒ con snapshots poblados (factor 6·S), **4-8 fotos locales bastan para agotar una cuota de 5 MB**.
- El propio código lo reconoce: `persistencia-local.js:83-89` — *"El modo local guarda TODO el estado como un único JSON con tope de 1 MiB. Las fotos base64 ... lo superan rápido y hacen que el push falle EN SILENCIO"* (ese 1 MiB refiere al canal de nube anterior; el mitigante actual es que el payload de nube viaja sin fotos y `restoreLocalLocPhotos()` :93 las reinyecta desde localStorage — o sea las fotos locales son **mono-navegador por diseño**).

### 3.3 Undo/redo en RAM

`UNDO_MAX = 30` (:23). Cada `markDirty()` empuja un string `JSON.stringify(project)` al stack (:534-538). Peor caso en memoria: **30 × S_proyecto** (+ redo). Un proyecto con 20 fotos de plan de rodaje a ~150 KB base64 **[estimación]** ≈ 3 MB de JSON ⇒ ~90 MB de strings retenidos, y **~3 MB de stringify síncrono por cada mutación** (por tecla en campos `change`, por clic en toggles). El undo no persiste (RAM), así que no compite por cuota, pero sí por GC y por el main thread.

---

## Hallazgos

1. **[Funcional, no solo perf] 50 handlers inline `on*=` sobreviven al desacople y están doblemente muertos bajo la CSP actual** (`grep -rEon 'on(click|change|input|drag[a-z]*|drop|...)="' src --include="*.js" | wc -l` → 50, todos drag&drop): `presupuesto-cotizacion.js:758` (`ondragstart="rowDragStart(event)" ondragover="rowDragOver(event)" ondrop="rowDrop(event)" ondragend="rowDragEnd(event)"` en cada `<tr>` del presupuesto), `plan-rodaje.js:304,314,338,375,754-755,787-788`, `locaciones.js:261-262,719,724`, `presupuesto-cotizacion.js:3002-3003,3023-3025`. La CSP (`index.html:35`) es `script-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com` — sin `'unsafe-inline'` ni `'unsafe-hashes'`, los atributos inline no se ejecutan; y aunque se ejecutaran, `rowDragStart` etc. son funciones module-scoped sin bridge (`grep -rn "window.rowDragStart\|window.prDragStart\|..."` → 0). Todo el reordenamiento drag&drop (filas de presupuesto, plan de rodaje, fotos de locaciones, scouting, bullets de cotización, hoja de llamado) estaría roto en el build con CSP estricta. `delegacion.js:54-58` sí escucha `dragover/dragleave/drop` pero **no** `dragstart/dragend`.
2. **xlsx eager + lazy duplicado**: `index.html:1282` carga xlsx 0.18.5 eager desde jsdelivr y `bd-excel.js:64` lo vuelve a declarar lazy desde **cdnjs** (mismo archivo, otro CDN). El eager solo es load-bearing para 2 exports de `gastos.js` (:1215, :1305) que usan el global sin `ensureXLSX()`. 41,3 % del transfer de arranque para una función de export ocasional.
3. **`presupuesto-cotizacion.js:740`** guarda con `typeof goLineaTieneCaja === 'function'` sobre un identificador **no importado**: solo no lanza porque `gastos.js:1618` aún hace `window.goLineaTieneCaja = goLineaTieneCaja` (bridge legacy). Si ese bridge se cosecha (van 73 `window.X =` restantes, `grep -rEn "window\.[A-Za-z_$]+\s*=" src | wc -l`), el guard pasa a `false` silenciosamente y las celdas derivadas de Gastos vuelven a ser editables: regresión sin error.
4. **Fuentes muertas + `@import` en cascada**: `index.html:1271-1273` (preconnect ×2 + CSS de Cormorant/Inter jamás referenciadas) y `src/styles.css:1` (`@import` de Poppins que sobrevive al bundle y encadena 3 RTTs). Además `--font-serif` apunta a Poppins (dist CSS: `--font-serif: "Poppins", ...`) — la "serif" del design system no existe.
5. **`index.html` con 83,9 % de comentario en producción** (93.485/111.409 B, 22 bloques): changelog completo V5→V8.6 servido a cada visitante; 28,6 KB gz evitables y superficie de information-disclosure (nombres, razón social, historia de bugs).
6. **`buildSaveObject()` escribe la BD por triplicado** (:75-79: `bdContactos`/`bdEmpresasById` canónicos + `bdPersonas`/`bdEmpresas`/`bdTalentos` legacy) en **cada autosave (2 s) y cada snapshot**: multiplicador directo sobre la cuota de localStorage descrita en §3.1.
7. **`legal.js:891`**: el único debounce de búsqueda del sistema (250 ms) desemboca en `renderLegal()` total que reconstruye el propio input de búsqueda ⇒ foco perdido mientras se tipea con pausas. Mientras tanto `bd.buscar` (`bd.js:1133`) no tiene debounce alguno.
8. **`markDirty()` = stringify del proyecto completo por mutación** (§2.4): el costo de deshacer está en el camino crítico de *cada* edición; con proyectos con imágenes base64, es trabajo síncrono de MBs por tecla en campos `change`. No hay snapshot estructural/incremental ni `requestIdleCallback`.
9. **`supabase-js@2` sin versión fijada** (`index.html:1284`): el peso (206.178 B hoy) y el comportamiento del arranque dependen de lo que jsdelivr resuelva ese día; incompatible con presupuestos de carga reproducibles y con subresource integrity.