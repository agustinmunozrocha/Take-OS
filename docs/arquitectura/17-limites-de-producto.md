# Límites de producto — i18n / lock-in Chile, compatibilidad de saves, soporte de navegador

Ámbito: `/home/juandlc/Trabajo/Take-OS/frontend` (solo lectura). Todas las cifras contadas con comando (indicado entre paréntesis).

---

## 1. Lock-in regional: inventario de lo hardcodeado a Chile

### 1.1 RUT (identificador tributario chileno como clave de dominio)

- **Normalización** — `frontend/src/modules/bd-excel.js:112`:
  ```js
  export function _normRutBD(rut) {
  ```
  Formatea a `xx.xxx.xxx-D`, descarta entradas <7 caracteres. Variante de dedupe `function _normRut(r)` en `bd-excel.js:36`.
- **Validación módulo 11** — `frontend/src/modules/perfil-onboarding.js:62`:
  ```js
  export function _rutValido(s) {
  ```
  Calcula dígito verificador (serie 2..7, `res===10 → 'K'`).
- **Consumidores** (grep `_normRutBD\|_rutValido`): onboarding bloquea el guardado del perfil si el RUT chileno es inválido (`perfil-onboarding.js:559-561`), validación en vivo del input (`perfil-onboarding.js:285`), completitud de perfil (`perfil-onboarding.js:376`); RUT de empresa en Configuración (`config.js:1127`, `config.js:1135`, `config.js:1147`, comentario de reuso en `config.js:1073`); alta de empresa en BD (`bd.js:357`); importación Excel de personas/empresas/casting (`bd-excel.js:377,399,519,541`) e **índice de dedupe por RUT** (`bd-excel.js:628,654`).
- Escape parcial para extranjeros: `_perfilEsExtranjero(prof)` (`perfil-onboarding.js:57-61`) — "extranjero" se infiere de que la región no matchee ninguna chilena vía `_regionCanonica` (`perfil-onboarding.js:45-53`), que itera `REGIONES_CHILE`. Es decir: el caso no-Chile existe solo como negación del catálogo chileno.

### 1.2 Códigos bancarios SBIF/CMF — **duplicados en dos módulos**

- `const BANCOS_SBIF = [` — `frontend/src/modules/bd-excel.js:152`, **20 entradas** (contado: `sed -n 152,172p | grep -c "codigo:"` → 20), nombres en MAYÚSCULAS, más mapa de alias `_BANCO_ALIAS` (`bd-excel.js:175`) y resolución por substring (`bd-excel.js:201-212`).
- `export const BANCOS_CHILE = [` — `frontend/src/lib/data.js:19`, **20 entradas** (contado igual), mismos códigos en title-case. Consumidores: `frontend/src/lib/ui.js:362`:
  ```js
  export function bancoCodigo(nombre) { const b = BANCOS_CHILE.find(x => x.nombre === nombre); if (b) return b.codigo; return (typeof _codigoBancoSBIF === 'function') ? gancho('_codigoBancoSBIF')(nombre) : ''; }
  ```
  (encadena AMBOS catálogos vía gancho), select de bancos `ui.js:366-369`, `_dalBancoNombre(codigo)` en `dal.js:118`.
- Uso final: generación de **nóminas de transferencias masivas formato Office Banking Santander** con moneda literal `'CLP'` — `frontend/src/modules/gastos.js:1190` y `gastos.js:1299` (`rows.push([cuentaOrigen, 'CLP', cuentaDestino, 'CLP', codigoBanco, rut, ...])`), y export contable con `Moneda: 'CLP'` en `gastos.js:1546` (columna pensada para Chipax, SaaS contable chileno; `usaChipax` en `lib/state.js:173`).

### 1.3 Modelo tributario chileno (SII: IVA, retención BHE/BTE, taxonomía DTE)

- Defaults en `frontend/src/lib/rates.js:12-16`:
  ```js
  export let IMPUESTO_HONORARIOS = 0.1525;      // concepto 'honorarios' (BHE)
  export let IMPUESTO_BTE = 0.1525;             // concepto 'retencion_bte' (BTE); default = BHE hasta tener dato
  export let IVA = 0.19;                        // concepto 'iva'
  export let FACTOR_BOLETA = 1 - IMPUESTO_HONORARIOS;
  export let FACTOR_BTE = 1 - IMPUESTO_BTE;
  ```
- Sobrescritura desde BD: `export async function dalBootTaxRates()` (`rates.js:24`) lee la tabla Supabase `tax_rates` (`rates.js:27`: `sb.from('tax_rates').select('concepto,tasa,vigente_desde,vigente_hasta')`) con **conceptos hardcodeados** `'iva'`, `'honorarios'`, `'retencion_bte'` (`rates.js:41-43`). Las *tasas* son data-driven; la *semántica* (retención sobre bruto que la productora entera al SII) es fija en código.
- Lógica tributaria central `frontend/src/lib/data.js:46-57`: `dteTieneRetencion(dte)` (data.js:46), `factorRetencionDte(dte)` (data.js:52-56), `montoNetoDesde(costoReal, dte)` / `montoBrutoDesde(liquido, dte)` (data.js:56-57). Taxonomía DTE del SII en `data.js:32-37` (`DTE_OPTIONS`: `boleta`, `factura`, `factura_exenta`, `boleta_terceros`) y `DTE_CON_RETENCION = ['boleta', 'boleta_terceros']` (data.js:40).
- La fórmula de costos del presupuesto depende del DTE: `export function calcCostoEmpresa(valor, cantidad, dte, sectionKey)` (`frontend/src/lib/calc.js:18`), que divide por `factorRetencionDte(dte)` cuando el DTE lleva retención (`calc.js:32-34`). Es decir, **el motor de presupuesto está acoplado al régimen tributario chileno**, no solo la UI.
- Documentos legales hardcodean ciudad: `function legalHoyLargo() { return 'Santiago, ' + new Date().toLocaleDateString('es-CL', ...); }` — `frontend/src/modules/legal.js:190`.

### 1.4 Regiones

- `export const REGIONES_CHILE = [...]` — `frontend/src/lib/data.js:17`, **16 regiones** (contado con python3 split). Consumidores: `regionSelectHTML` (`ui.js:354-357`), onboarding (`perfil-onboarding.js:359`), `_regionCanonica` (`perfil-onboarding.js:45-53`).

### 1.5 CLP como única moneda — `project.currency` es cosmético

- `grep -rn "currency" frontend/src --include="*.js"` → **3 ocurrencias**, las tres son *escritura* del literal `'CLP'` al construir un proyecto: `info-proyecto.js:476`, `kanban.js:263`, `dal.js:1324`. **Cero lecturas** del campo en cálculo o render: es dead-weight en el modelo.
- Los formateadores asumen peso chileno sin decimales: `export function formatCLP(amount)` (`calc.js:101`, abrevia `$xM`), `export function fmtMoney(n)` (`calc.js:110`, `'$' + Math.round(n).toLocaleString('es-CL')`), `export function fmtDelta(n)` (`calc.js:116`), `export function parseMoneyCLP(raw)` (`calc.js:195`, heurística de separadores es-CL/en-US). Redondeo a peso entero como invariante documentado (`calc.js:53`: "entero CLP, consistente con calcCostoEmpresa").

### 1.6 Formato es-CL y ausencia total de capa i18n

- `'es-CL'` aparece **33 veces** (`grep -rn "es-CL" --include="*.js" | wc -l`), repartidas en 13 archivos (plan-rodaje 5, presupuesto-cotizacion/persistencia-local/legal/calc 4 c/u, ...). Composición: **22** `toLocaleString` + **10** `toLocaleDateString` (grep -c de cada uno) + 1 comentario de CSV (`presupuesto-cotizacion.js:3504`: separador `';'` "Excel es-CL" con BOM UTF-8). **Todas** las llamadas `toLocale*` pasan `'es-CL'` inline — el grep de `toLocaleString|toLocaleDateString|toLocaleTimeString` excluyendo `es-CL` devuelve 0 líneas. **0 usos de `Intl.`** (grep).
- i18n: **0 archivos de locale** (`find src -name "*locale*" -o -name "*i18n*" -o -name "*.po" -o -name "*lang*"` → vacío), **0 librerías** (package.json no tiene `dependencies`; la única entrada es `devDependencies.vite ^7.0.0`), `<html lang="es">` fijo (`frontend/index.html:2`). Los strings de UI viven incrustados en template literals de los 25 módulos; solo `showToast` suma **368 llamadas** con título/cuerpo en español (suma de `grep -c showToast` por archivo).
- **Conclusión de coste**: internacionalizar no es "agregar un diccionario". Implica (a) extraer miles de literales embebidos en HTML-por-string sin ningún punto de indirección actual; (b) parametrizar locale en 32 llamadas `toLocale*` hoy inline; (c) abstraer el modelo de dominio país-específico: RUT como clave de dedupe de la BD (`bd-excel.js:628`), taxonomía DTE en el motor de costos (`calc.js:18`), retención SII en `data.js:52`, catálogo bancario SBIF en el flujo de pagos (`gastos.js:1190/1299`) y regiones en onboarding. Lo único ya preparado es la tasa numérica (tabla `tax_rates`). El lock-in es de **modelo de datos**, no solo de presentación.

---

## 2. Compatibilidad de formatos de guardado

### 2.1 Versionado declarado vs. validado

- `const SAVE_FORMAT_VERSION = 5;` — `frontend/src/modules/persistencia-local.js:43` (comentario: "V7.3: modelo unificado (bdContactos + bdEmpresasById); mantiene proyecciones legacy para compat con clientes V7.2.x"). El objeto exportado lo incluye (`persistencia-local.js:61-62`: `format: 'takeos-save', version: SAVE_FORMAT_VERSION`).
- **La validación NO mira la versión**. `function validateSaveObject(obj)` (`persistencia-local.js:106-114`) chequea solo: `obj.format !== 'takeos-save'`, `Array.isArray(obj.projects)`, y por proyecto `typeof p.id === 'string' && p.data`. Cualquier JSON con esa forma pasa, con `version` 1, 4, ausente o no-numérica.
- En `importSaveFromInput` (`persistencia-local.js:186-241`) la única comprobación es `persistencia-local.js:209`: `if (obj.version > SAVE_FORMAT_VERSION)` → toast warning "Se intentará cargar igual" **y continúa**. Versiones antiguas o ausentes: ni aviso ni log. Además el import "Cargar OS" es **merge aditivo** vía `mergeAddProjectsFromSave(obj)` (`persistencia-local.js:175-185`): agrega proyectos por id nuevo y su única curación es `if (p.data && !Array.isArray(p.data.locaciones)) p.data.locaciones = [];` (línea 181) — no pasa `hydrateContactStore` ni migradores en ese punto.
- `applyLoadedState(obj)` (`persistencia-local.js:116-147`) — reemplazo total en sitio (muta `PROJECTS`/`TRASH`/`BD_*` const), llama `hydrateContactStore(obj)` (línea 136) y termina con `navigateToControlRoom(); renderMetrics(); renderKanban(); clearDirty();`. Hoy solo lo invoca `restoreSnapshot` (`persistencia-local.js:303`), que tampoco valida versión (JSON.parse directo del snapshot, líneas 288-292).
- Save por-proyecto: `const PROJECT_FORMAT_VERSION = 1;` (`persistencia-local.js:366`) se escribe al exportar (`persistencia-local.js:378`) pero `importSingleProjectFromInput` (`persistencia-local.js:401-478`) **nunca lee `obj.version`** — valida solo `obj.format !== 'takeos-project' || !obj.project || typeof obj.project.id !== 'string'` (línea 426). Asimetría con el save global (que al menos advierte "más nuevo").

### 2.2 Migradores in-situ existentes (curación lazy por subsistema, no dirigida por versión)

Inventario (grep `-i "migraci|migrate|migrar"` filtrando comentarios de mudanza):

| Migrador | Ubicación | Qué cubre |
|---|---|---|
| Plan de rodaje `dd.planes` → unidades | `plan-rodaje.js:113-119` (comentario literal "migración V7.7 → V7.8") | shape V7.7 |
| Plan de rodaje `dd.variantes {A,B}` → unidades | `plan-rodaje.js:120-124` ("migración V7.6 → V7.8") | shape V7.6 |
| `prMigrateFila(f)` | `plan-rodaje.js:139-148` | rellena campos por fila (`id`, `tipo`, `dur`, `anchor`, `paralelo`, `escPlano`, `accion`); se aplica a cada fila/banco en `plan-rodaje.js:135` |
| `hydrateContactStore(obj)` | `lib/modelo.js:206-225` | save nuevo (`bdContactos`+`bdEmpresasById`) o proyección legacy (`bdPersonas`/`bdEmpresas`/`bdTalentos` → `ingestLegacyIntoContactos()`) |
| `migrateProjectLocaciones(project)` | `lib/modelo.js:450-467` | V8.2: `hojaLlamado.locaciones` → `BD_LOC` + `project.data.locaciones`; flag idempotencia `d._locMigrated`; disparado por `ensureProjectLoc` (`modelo.js:469`) |
| Logo único V11.2 → múltiple | `config.js:672` ("migración suave") | config empresa |
| Cargos localStorage V11.2 → tabla `project_cargos` | `cargos.js:52` ("Migración one-shot") | estado provisional |

Contrato real: **la clave `version` del archivo jamás selecciona una rama de código**; toda la compatibilidad es curación estructural lazy en el momento del uso/render, subsistema por subsistema.

### 2.3 Versiones sin ruta de migración

- **Plan de rodaje pre-V7.6**: si un día no trae ni `dd.planes` ni `dd.variantes`, el else de `plan-rodaje.js:124-126` crea `prNuevaUnidad('Unidad 1', 'Plan A')` **vacía** — cualquier estructura anterior a V7.6 con otro nombre de campo se descarta en silencio (pérdida de datos sin aviso).
- **Saves version 1–4 en general**: se aceptan sin advertencia; sobreviven solo en la medida en que los healers de la tabla anterior cubran su shape. No existe registro/telemetría de "cargué un save viejo".
- **Autosave localStorage**: `LS_KEY = 'takeos_autosave_v1'` (`persistencia-local.js:44`) tiene exactamente **3 usos** (grep): definición (44), lectura solo-fotos en `restoreLocalLocPhotos` (95) y escritura en `autosaveNow` (491). No existe ruta que rehidrate `PROJECTS` completo desde el autosave — ver Hallazgo 4.

---

## 3. Supuestos de navegador

### 3.1 Sin targets declarados

- `frontend/vite.config.js` (10 líneas, completo) solo define `base: './'` y `build.outDir: 'dist'` — **no hay `build.target`**. `frontend/package.json` no tiene campo `browserslist` ni `@vitejs/plugin-legacy` (única dependencia del proyecto: `"vite": "^7.0.0"`, devDependency). Target efectivo = default de Vite 7: `'baseline-widely-available'` (≈ Chrome/Edge 107+, Firefox 104+, Safari 16.0+). Nota: ese target solo transpila *sintaxis* (esbuild); **no polyfillea APIs de runtime ni CSS**.

### 3.2 Features modernas y sus fallbacks (contado con grep en `frontend/src`)

| Feature | Usos | Fallback |
|---|---|---|
| `crypto.randomUUID` | 2 sitios: `lib/modelo.js:238` y copia duplicada `modules/presupuesto-cotizacion.js:1338` (ambos dentro de `function _clientUuid()`; la razón de la copia está comentada en `modelo.js:234-236`) | Sí: guard + generador `getRandomValues`/`Math.random`; el requisito de secure context está documentado en `presupuesto-cotizacion.js:1333-1336` |
| `navigator.clipboard.writeText` | 6 (grep) | Mixto: `invitaciones.js:60` cae a `document.execCommand('copy')`; `notificaciones.js:344` hace guard de existencia; `cargos.js:172`, `config.js:427`, `config.js:752` solo try/catch (fallo silencioso: no rompe, no copia) |
| `gesturestart`/`gesturechange` (propietario Safari) | `presupuesto-cotizacion.js:4086-4087`, dentro de `CotPreview` (`export const CotPreview = {` en 4070) | Parcial: el pinch de trackpad en Chrome/Firefox llega como `wheel` + `ctrlKey`, manejado en `presupuesto-cotizacion.js:4080`; el comentario `4067` lo reconoce ("wheel+ctrlKey y gestos de Safari") |
| CSS `:has()` | 3: `styles.css:1074`, `styles.css:1729`, `styles.css:3190` | No (Vite no transforma selectores; Firefox <121 los ignora). Impacto cosmético: resaltado de filas con checkbox y un borde |
| `structuredClone` | **0** (grep) | n/a |
| `Array.prototype.at` | **0** (grep `\.at(-`) | n/a |
| Optional chaining `?.` | 32 ocurrencias (grep -Eo) | Sintaxis: transpilable por esbuild si el target lo exigiera; con el default no se transforma |
| Nullish `??` | 6 | ídem |
| `String.replaceAll` | 6 (ES2021, API de runtime — no polyfilleable por target) | No |
| `Object.fromEntries` | 4 — una en carga de módulo: `data.js:38` (`DTE_LABEL`); si el motor no la soporta, la app no arranca | No (ES2019, dentro del baseline) |
| `localStorage` bloqueado (sandbox) | Curado: `function hasLS()` `persistencia-local.js:48-55` + try/catch documentado (`persistencia-local.js:40-42`) | Sí |
| `Intl.*` | **0** | n/a |

**Contrato implícito de soporte**: navegadores evergreen ≥ baseline 2022 (Safari 16+), sin declaración explícita en el repo, sin detección de capacidades al boot (más allá de `hasLS` y los guards puntuales de arriba), sin plugin legacy. El único doble-camino real de UX es el zoom del preview de cotización (Safari gestos / resto wheel+ctrl).

---

## Hallazgos

1. **Catálogo bancario duplicado** — `BANCOS_SBIF` (`bd-excel.js:152`, 20 entradas, MAYÚSCULAS) y `BANCOS_CHILE` (`data.js:19`, 20 entradas, title-case) codifican los mismos 20 códigos SBIF en dos módulos sin fuente común; `bancoCodigo` (`ui.js:362`) incluso consulta ambos encadenados vía gancho `_codigoBancoSBIF`. Agregar/renombrar un banco exige tocar dos listas y un mapa de alias (`bd-excel.js:175`).
2. **Versionado de saves declarativo pero no operativo** — la única comparación de `version` en todo el sistema es `obj.version > SAVE_FORMAT_VERSION` con warning no bloqueante (`persistencia-local.js:209`); `validateSaveObject` (`persistencia-local.js:106`) ignora la versión; `importSingleProjectFromInput` (`persistencia-local.js:401`) no la lee pese a declararse `PROJECT_FORMAT_VERSION = 1` (`persistencia-local.js:366`); `restoreSnapshot` (`persistencia-local.js:281`) tampoco.
3. **Pérdida silenciosa pre-V7.6 en plan de rodaje** — el else de `plan-rodaje.js:124-126` sustituye por una unidad vacía cualquier día cuyo shape no sea `planes` (V7.7) ni `variantes` (V7.6); no hay aviso al usuario ni log.
4. **El "AIRBAG" de autosave no restaura nada** — el comentario de cabecera (`persistencia-local.js:37-42`: "2. Autoguardado en localStorage → AIRBAG dentro del mismo navegador") promete una capa de recuperación, pero `LS_KEY` solo se escribe (`persistencia-local.js:491`) y se lee únicamente para reinyectar fotos de locaciones (`restoreLocalLocPhotos`, `persistencia-local.js:93-104`). No existe ruta de rehidratación completa del estado desde localStorage (grep `LS_KEY` → 3 usos).
5. **Merge de saves sin curación inmediata** — `mergeAddProjectsFromSave` (`persistencia-local.js:175-185`) inserta proyectos entrantes en `PROJECTS` sin pasar `hydrateContactStore`/`ensureProjectLoc`; la migración queda diferida a los healers lazy, de modo que cualquier lector de `p.data` que no pase por `ensureProjectLoc` ve el shape viejo.
6. **Comentario mentiroso en rates.js** — la cabecera (`rates.js:4-7`) afirma que el módulo escribe los valores en `window`, pero `_espejo()` (`rates.js:18-21`) tiene el cuerpo vacío tras la purga D4c; el contrato documentado ya no corresponde al código.
7. **Lock-in de banco, no solo de país** — el flujo de pagos masivos genera filas con moneda `'CLP'` literal y layout de "Office Banking de Santander" (`gastos.js:1190`, `gastos.js:1299`; formato documentado en `bd-excel.js:149-151`), y el export contable apunta a Chipax (`gastos.js:1546`, `usaChipax` en `state.js:173`).
8. **`project.currency` es campo muerto** — 3 escrituras `'CLP'` (`info-proyecto.js:476`, `kanban.js:263`, `dal.js:1324`), 0 lecturas; da apariencia de multi-moneda que el sistema no tiene.
9. **`_clientUuid` duplicada** — `lib/modelo.js:237` y `modules/presupuesto-cotizacion.js:1338` mantienen dos copias idénticas del generador UUID con fallback; la duplicación está comentada como deliberada (`modelo.js:234-236`, gap de arranque) pero es deuda a consolidar.