# Informe — Convenciones de código, calidad y deuda técnica documentada
**Repo:** `/home/juandlc/Trabajo/Take-OS` · rama `etapa4-integracion` · 40 archivos JS en `frontend/src/` (25.327 líneas, `wc -l`), más `frontend/index.html` (1.556 líneas). 251 commits en la rama (`git log --oneline | wc -l`), 167 con formato convencional `tipo(scope):` (`git log --pretty=%s | grep -cE '^(feat|fix|merge|chore|docs|refactor)\('`).

---

## 1. Convenciones de nombres

### 1.1 Exports por familia de prefijo

316 exports únicos en los 40 archivos (script Python propio sobre `export (async )?function|const|let|class` + `export { … }`). Los archivos con más superficie exportada: `lib/state.js` (39), `modules/dal.js` (33), `lib/ui.js` (29), `modules/presupuesto-cotizacion.js` (24), `lib/data.js` (20), `lib/calc.js` (16).

| Familia | Exports | Semántica observada | Ejemplos reales |
|---|---|---|---|
| `_privado` (`_x…`) | 64 | "privado de módulo pero cruzado por un consumidor puntual"; el `_` sobrevive a la extracción del monolito | `_authBlockWriteToast` (lib/auth.js), `_bootCoverHide`/`_bootCoverShow` (lib/boot.js), `_clientUuid` (lib/modelo.js:237) |
| MAYÚSCULAS | 55 | constantes/almacenes canónicos | `BD_CONTACTOS` (lib/state.js:136), `STATES_WITH_REAL_COST` (lib/state.js:92), `TAKEOS_VERSION = 'V11.14.0'` (lib/state.js:222) |
| `dal*` | 23 | capa de acceso a datos Supabase; sub-familias `dalBoot*` (carga inicial), `dalGuardar*`, `dalCargar*` | `dalBootContactos`, `dalGuardarCargos`, `dalResolveIdentidad` (modules/dal.js) |
| `render*` | 14 | render completo de un módulo/vista | `renderKanban`, `renderLocaciones`, `renderBDPersonas` |
| `set*` | 10 | setters D3a de estado global — única vía de escritura de los `export let` de state.js | `setOrgId`, `setSource`, `setTieneEmpresa` (lib/state.js:231-246) |
| `open*`/`close*` | 8 / 2 | apertura/cierre de modales o paneles | `openConfigPanel`/`closeConfigPanel` (modules/config.js:129), `closeModal` (lib/ui.js) |
| `fmt*/format*` | 6 | formateadores puros | `fmtMoney`, `formatCLP`, `fmtPct` (lib/calc.js) |
| `loc*` | 4 exportados | Locaciones | `locFullAddress`, `locPrimaryContact` |
| `go*` | 2 exportados | Gastos ("g-o" = gastos/operaciones) | `goCotizadoTotal`, `goMovs` |
| `ntf*`, `_cp*` | 1 / 1 | Notificaciones / Config-Panel | `ntfOpenFromHoja`, `_cpTourInicialQuizas` |

**Las familias grandes viven como funciones internas, no como exports.** Barrido de las 1.479 declaraciones de función nombradas (1.461 nombres únicos; script Python sobre `function X(` y `const X = (…) =>`):

| Familia | Funciones | Concentración (archivo: nº) |
|---|---|---|
| `_privado` | 423 | config.js (118), dal.js (56), presupuesto-cotizacion.js (34), calculadoras.js (23) |
| `go*` | 88 | **gastos.js (87)** — prefijo-módulo casi perfecto |
| `pr*` | 81 | **plan-rodaje.js (81)** — 100 % confinado |
| `ntf*` | 48 | **notificaciones.js (48)** — 100 % confinado |
| `loc*` | 47 | **locaciones.js (47)** — 100 % confinado |
| `render*` | 47 | presupuesto-cotizacion.js (12), bd.js (7) |
| `dal*` | 46 | dal.js (39) |
| `_cp*` (config-panel) | 40 | **config.js (40)** — 100 % confinado |
| `open*` | 28 | bd.js (10), calculadoras.js (4), legal.js (4) |
| `_esp*` (espacio) | 12 | espacio.js (12) |
| `inv*` | 4 | invitaciones.js (`invAceptar`, `invCompletarPerfil`, `invCopiarLink`, `invRechazar`) |

**Invariante de facto:** el prefijo funciona como namespace de módulo (pre-ESM); tras la modularización cada familia quedó confinada a su archivo homónimo con fuga ≈ 0 (única excepción: `goCotizadoTotal` referida desde presupuesto-cotizacion.js).

`hec/he*` **ya no es familia de funciones**: son variables de estado local de calculadoras. `modules/calculadoras.js:21-26` declara `let _hep; let _hec; let _crc; let _calcModo; let _calcTipo; let _calcMonto;` todas con el comentario literal `// D4c: estado propio del módulo (antes window._hec, era de los handlers inline)`. Sobreviven `function setHeHoras(sectionKey, dept, idx, raw)` (calculadoras.js:369) y `openHeProyectoDefault`/`openHorasExtraCalc` (calculadoras.js:623-624).

### 1.2 Namespaces de acciones delegadas (tercera capa de naming)

24 namespaces registrados vía `registrarAcciones(ns, mapa)`, 364 acciones (script propio, ver §5): `go`:50, `bd`:40, `loc`:37, `ntf`:32, `lgl`:27, `pre`:23 (presupuesto), `calc`:17, `tm`:16 (tareas), `app`:15 (topbar/sidebar, registradas en lib/boot.js:706-724 y consumidas solo por `index.html` estático), `cfg`:14, `cargo`:13, `info`:13, `ui`:11, `esp`:11, `crew`:10, `pr`:9, `doc`:7, `kanban`:6, `inv`:4, `rodajes`:4, `snap`:2, `boot`/`buscador`/`plan`:1. El namespace replica el prefijo de la familia de funciones del módulo.

### 1.3 Comentarios de era

Dos generaciones de marcado conviven:

**(a) Eras de la migración/desacople** — documentan *procedencia* ("extraído de index.html (Etapa A2)"), *reubicación* ("→ movido a src/lib/data.js (Etapa B3)") y *mecanismo introducido* ("D4c: estado propio del módulo (antes window._X…)"). Conteos (`grep -rho "Etapa X" --include="*.js"` para A/B/C con prefijo; `grep -rhoE '\bDx\b'` para D):

| Era | Menciones | Era | Menciones |
|---|---|---|---|
| Etapa 1 | 20 | Etapa C1..C6 | 6/4/6/12/13/3 |
| Etapa 2 | 26 | `C5` bare | 17 |
| Etapa A1..A6 | 3/5/8/1/2/7 | `C6` bare | 10 |
| Etapa B1..B3 | 7/5/9 | `D1`/`D2`/`D3`/`D3a` | 2/27/3/3 |
| — | — | `D4`/`D4b`/`D4c` | 1/25/22 |

La forma `(D3)` entre paréntesis aparece 1 vez (`grep -rhoE '\(D[0-9][a-c]?\)'`); `(D1)` como tal 0 — las 2 menciones `\bD1\b` son `main.js:41` ("C6/D1: última entrada del manifiesto…") y `modules/kanban.js:349` ("aristas diferidas de D1"). Cada archivo declara su era de extracción en la cabecera (ver §6).

**(b) Versiones de producto `Vx.y[.z]`** — la convención anterior y aún dominante: **567 menciones**, 132 tags distintos (`grep -rhoE '\bV[0-9]+\.[0-9]+(\.[0-9]+)?\b' | sort -u | wc -l`), desde V5.2.1 hasta V11.31. Documentan *decisiones de producto* con changelog inline (p.ej. lib/state.js:13-18 explica `adminMode` citando "V5.3 (Nota 2)"). Top: V11.15.0 (25), V5.3 (18), V7.1 (17).

---

## 2. Manejo de errores como sistema

### 2.1 Canales `console.*` con tag

90 llamadas de consola en total y **cero `console.log`** (`grep -rho "console\.\(error\|warn\|info\|log\)" | sort | uniq -c`): 57 `console.error`, 30 `console.warn`, 3 `console.info`. El tagging con corchete es sistemático (`grep -rhoE "console\.(error|warn|info)\('\[[a-zA-Z-]+\]"`):

- **`[dal]`** — canal dominante: 26 error + 6 warn (modules/dal.js). Patrón uniforme: `console.error('[dal] guardar contacto', c.id, e)` (dal.js:695) + toast de degradación.
- **`[delegacion]`** — 3 error, los tres puntos de fallo del dispatcher (lib/delegacion.js:42 acción sin registrar, :45 `data-args` inválido, :47 excepción de la acción). Contrato: *ninguna acción rota escala; se loguea y se traga* (`try { fn(args, el, ev); } catch (e) { console.error('[delegacion] acción', el.dataset.accion, e); }`).
- **`[ganchos]`** — 2 error + 1 warn (lib/ganchos.js:19 redefinición, :26 `sin definir:` en invocación, :32 `valor sin definir:`). Contrato: *un gancho sin definir grita con su nombre y devuelve `undefined`, jamás lanza*.
- Resto: `[storage]` 6w, `[perfil]` 5e+2w, `[auth]` 4w+1i, `[supabase]` 2e+1i, `[inv]` 3w, `[restaurar]`/`[archivar]` 3e c/u, `[boot]`/`[autosave]`/`[snapshots]`/`[org]`/`[cfg]`/`[pr]`/`[pre]`… 1 c/u. Solo **2 `console.error` sin tag**, ambos en lib/nav.js:206 y :229 (dispatcher `renderModule`).

### 2.2 try/catch

**452 `try {`** y 458 `catch (` (`grep -rhoE '\btry\s*\{' | wc -l`) — densidad 1 try cada 56 líneas. Concentración por archivo (`grep -rc "try\s*{"`): config.js 74, dal.js 72, boot.js 53, presupuesto-cotizacion.js 25, gastos.js 24, espacio.js 24. El patrón mayoritario es el *catch-vacío defensivo de una línea*: `try { … } catch (e) {}` (herencia del monolito: "ante cualquier error, arranca TakeOS normal", lib/boot.js:563).

### 2.3 Cadenas async y promesas huérfanas

- **Solo 7 `.catch(`** en todo src (`grep -rho '\.catch(' | wc -l`): espacio.js 2, cargos.js 2, locaciones.js 1, config.js 1, boot.js 1.
- La **espina dorsal del boot sí está protegida**: `lib/boot.js:578`, dentro de `export function arrancarTakeOS()` (boot.js:573), encadena 9 `dalBoot*` con `.catch(function(e){ console.error('[boot] cadena dal interrumpida', e); try { _bootCoverHide(); } catch (_) {} })`.
- **No existe manejador global**: 0 resultados para `unhandledrejection|window.onerror|addEventListener('error'` en src e index.html.
- **35 llamadas fire-and-forget** a funciones async (117 declaradas, 35 en dal.js) en posición de sentencia sin `await/.then/.catch` (script propio): p.ej. `dalGuardarEmpresa(BD_EMPRESAS_BYID[_eid]);` (bd.js:366), `dalGuardarContacto(base);` (bd.js:1107), `dalGuardarCargos(project);` (cargos.js:86), `dalInvitar(email, 'externo', codigo, row.id, project.id)` (cargos.js:378), `resolverEspacioYArrancar();` (boot.js:664; invitaciones.js:74,163,170,200), `_empCargarEquipo();` ×7 (config.js:286-423), `notifCargar();` (notificaciones.js:89,190). Mitigante: las `dal*` capturan internamente (`dalGuardarContacto` — dal.js:673 — hace `try { … } catch { console.error('[dal] …'); showToast(…); return { ok:false, error:e } }`), así que el rechazo real es raro pero **no hay red para las que no lo hagan**.
- **12 sentencias `.then(` sin `.catch`** en el mismo statement (heurística ±6 líneas): cargos.js:105,112,374; config.js:389; documentos.js:149; espacio.js:155,224; gastos.js:884; legal.js:804; notificaciones.js:345; plan-rodaje.js:525.
- **Anti-patrón detectado**: `try { notifCargar(); } catch (e) {}` (notificaciones.js:120,162), `try { _empCargarEquipo(); } catch (e) {}` (config.js:243-244), `try { resolverEspacioYArrancar(); } catch (e) {}` (config.js:1062) — el try/catch síncrono **no captura el rechazo** de la función async; solo protege el despacho.

---

## 3. Código muerto o sospechoso restante

### 3.1 Exports sin importador

20 de 316 exports no aparecen en ningún `import { … }` (script de cruce exports/imports). **Ninguno es función muerta**: todos tienen consumo interno o vía ganchos; lo muerto es el **modificador `export`**:

- Consumidos vía `define()`/`gancho()`/`valor()` (el export es residuo): `ESPACIO_DEMO` (espacio.js:113, consumido por `valor('ESPACIO_DEMO')` en boot.js:586), `_espConstruir` (espacio.js:133 ← `gancho('_espConstruir')` boot.js:216,625,629), `_espInyectarCtaProductora`/`_espInyectarHerramientas`/`_espInyectarInvitaciones` (espacio.js:352,375,402), `_swToggle` (espacio.js:30 ← boot.js:708), `renderEspacioUsuario` (espacio.js:242), `closeConfigPanel`/`_configPanelOpen`/`abrirFlujoCrearProductora`/`_cpTourInicialQuizas` (config.js:129,130,996,1405 ← boot.js:64,599,578), `renderNotificaciones` (notificaciones.js:658 ← `gancho('renderNotificaciones')` nav.js:145).
- Solo uso intra-archivo (export gratuito): `IMPUESTO_HONORARIOS`, `IMPUESTO_BTE`, `TAX_RATES_SOURCE` (rates.js:12,13,17), `confirmDeleteProject` (kanban.js:310, usado solo por la acción `kanban.delConfirm` kanban.js:356), `projectAttentionCount`/`projectsNeedingAttention`/`projectClientNet`/`renderProjectCard` (kanban.js:49,55,80,95).

### 3.2 Ganchos: productores/consumidores

108 nombres con `define()`, 105 consumidos por `gancho()`/`valor()`; **0 consumidos sin define** (la "compuerta 2" del commit 4c8067b se cumple) y **3 defines sin consumidor**: `_pdCookiesBootCheck` (config.js:2164 — se consume por import directo en espacio.js:13, el define sobra), `_setOrgActiva` (boot.js:730 — ídem, import en espacio.js:16), `goSavePresup` (gastos.js:1694 — sin consumidor alguno del gancho; la función vive vía la acción `go.guardarPresup` gastos.js:1647).

### 3.3 window: bridges sin lector

De 194 ocurrencias `window.*` (`grep -rho "window\.[A-Za-z_$][A-Za-z0-9_$]*" | wc -l`), descontando APIs de navegador y comentarios quedan 93 propiedades de aplicación. **64 son solo-escritura** (`window.X = X` sin ningún lector `window.X` en src); de ellas, 16 tienen lector encubierto vía guard de global desnudo `typeof X === 'function'` (p.ej. `if (typeof crewAddToBD === 'function') { gancho('crewAddToBD')(nombre); }` lib/ui.js:162; `typeof _codigoBancoSBIF` lib/modelo.js:23 y lib/ui.js:362; `typeof _regionCanonica` lib/ui.js:353; `typeof renderGastos`/`renderHojaLlamado` presupuesto-cotizacion.js:1116-1117). Las **48 restantes no tienen ningún lector**: `window.newProject` (kanban.js:347), `window.updateInfoField` (info-proyecto.js:548), `window.toggleAdminMode` (admin.js:390), `window.setHeHoras` (calculadoras.js:625), `window.showToast`/`safeUrl`/`escapeHtml`/`supabaseInit`/`dalBootTaxRates`/`STATE` (main.js:43-48), `window.openSnapshotsModal` (persistencia-local.js:623 — cuyo comentario "`config.js + buscador.js` la llaman" es falso: ambos usan gancho/import), etc. Son la cosecha pendiente del cierre D4c ("27/27 props sin lector", commit e2e9c5a).

### 3.4 TODO/FIXME

**2 TODOs reales y 0 FIXME/HACK/XXX** (`grep -rnE "//\s*TODO|TODO:"` filtrando el español "TODO el/TODOS"): `lib/ui.js:704 // TODO V5.2: aplicar filtro real al kanban` y `lib/ui.js:713 // TODO V5.2: cambiar a vista lista cuando aplique` — ambos fósiles de V5.2 (la app va en V11.x). La deuda se marca en cambio con **`PENDIENTE`**: lib/boot.js:567 (bloque "PENDIENTE (ver handoff al BD Expert): motor de organización activa… modo externo… perfil personal") y lib/ui.js:783 (ver Hallazgo H6).

---

## 4. Consistencia de los 3 mecanismos de intercom

Los mecanismos y sus firmas reales:
1. **Imports ESM** (aristas hacia-abajo).
2. **Ganchos** (aristas hacia-arriba): `export function define(nombre, fn)` / `export function gancho(nombre)` / `export function valor(nombre)` (lib/ganchos.js:18,23,31). Invariante documentado en cabecera: "Todos los define() corren al EVAL del productor… toda invocación es runtime post-arranque — nunca hay carrera". 110 llamadas `define(`, 170 `gancho(`, 7 `valor(`.
3. **Delegación** (DOM→módulo): `export function registrarAcciones(ns, mapa)` (lib/delegacion.js:16), `export function accionHTML(accion)` (variádica, delegacion.js:24), dispatcher `function despachar(ev)` (delegacion.js:35) con UN listener por tipo para `['click','input','change','keydown','dblclick','mousedown','paste','submit','dragover','dragleave','drop']` en burbuja (delegacion.js:54) y `['focus','blur']` en captura (delegacion.js:57). Firma de toda acción: `(args, el, ev)` (contrato en cabecera, delegacion.js:10-11).

### 4.1 Chequeo oro: `data-accion` registradas vs referenciadas

Script propio: parseo de los mapas de `registrarAcciones` con eliminación previa de comentarios y balance de llaves (claves de nivel 1), contra referencias literales `accionHTML('ns.x')` + `data-accion="ns.x"` en src **y** en `index.html` estático. Resultado:

- **364 acciones registradas / 364 referenciadas / 0 registradas jamás referenciadas / 0 referenciadas jamás registradas.** Simetría perfecta en ambas direcciones.
- 0 claves duplicadas entre llamadas (`Object.assign` en delegacion.js:17 permitiría el merge silencioso, pero no se usa para pisar).
- 0 referencias dinámicas fuera de la propia implementación de `accionHTML` (delegacion.js:24,29).
- Nota metodológica: las 15 `app.*` + `app.logout` solo se referencian desde `index.html:1296-1523` (sidebar/topbar estáticos); un cruce que ignore el HTML estático da falsos positivos.

### 4.2 Mezclas raras detectadas

- **`sb` como global implícito en dal.js y rates.js**: 13 módulos importan limpio (`import { sb } from '../lib/supabase.js'` — invitaciones.js:8, espacio.js:11, etc.), pero **`modules/dal.js` (68 usos de `sb` desnudo, `grep -coE '\bsb\b'`) y `lib/rates.js` (dalBootTaxRates, rates.js:25) no lo importan**: resuelven vía `window.sb`, apuntalado por `if (!('sb' in window)) window.sb = null;` (lib/supabase.js:16, con comentario que lo admite: "los guards `if (!sb)` del DAL nunca pueden lanzar ReferenceError"). Nota: el import tampoco serviría tal cual — `export let sb` se reasigna en `supabaseInit()` (supabase.js:21) y el binding vivo sí lo propagaría, pero el patrón elegido fue el global.
- **Escritura a global desnudo**: `DAL_SESSION_UID = sess.user.id || null;` (dal.js:482) — asignación sin declarar que solo no lanza porque `lib/state.js:52` creó `window.DAL_SESSION_UID = null` antes. Convive con los setters formales `setOrgId(v)`… (state.js:231-246): dos vías de escritura de estado de sesión.
- **Triple mecanismo en un mismo punto**: `try { const _c = (typeof _regionCanonica === 'function') ? gancho('_regionCanonica')(cur) : null; … }` (lib/ui.js:352) — guard sobre el bridge window + invocación por gancho; ídem ui.js:162-163 (`crewAddToBD`/`openPersonaForm`).
- **`window.__TAKEOS_USER`** lectura/escritura cruzada boot.js:255 ↔ dal.js:492,513,559 y **`window._ORG_EPOCA`** (dal.js:1851,1857) y **`window._persisResetOrg`** (boot.js:160 ↔ persistencia-local.js:25): los 3 últimos estados window *vivos* con productor y consumidor reales — candidatos naturales a state.js/ganchos.

---

## 5. Testing e infra de calidad

**No existe nada. Evidencia:**
- `find` por `.eslintrc*`, `eslint.config*`, `tsconfig*`, `.prettierrc*`, `jest.config*`, `vitest.config*`, `*.test.js`, `*.spec.js`, directorios `test*`/`__tests__` (excluyendo node_modules): **0 resultados**.
- `frontend/package.json`: única devDependency `"vite": "^7.0.0"`; scripts solo `dev/build/build:staging/preview`. Sin `test`, sin `lint`.
- Hooks de git: `ls .git/hooks/ | grep -v sample` → vacío. Sin husky.
- CI: `.github/workflows/deploy.yml` únicamente — build Vite + publicación a GitHub Pages con selección de modo por repo (staging vs producción); **ningún job de lint/test/typecheck**.
- Lo único parecido a tooling de calidad es extra-repo: `.claude/settings.json` (untracked) con allowlist de comandos (`node --check *`, `git *`, …), y las "compuertas" citadas en commits (a040649: "compuerta nueva: uso de gancho/valor/define exige su import"; 4c8067b: "compuerta 2 … (105/105 OK)") que fueron **chequeos ad-hoc de sesión, no scripts versionados** (0 archivos en el repo contienen esa lógica).

---

## 6. Documentación existente

- **Sin README en la raíz ni en frontend/** (`find -maxdepth 3 -iname "README*"`): solo `supabase/queries/README.md` y `supabase/catalogos_globales/README.md`.
- **`docs/CLAUDE.md`** (94 líneas): "instrucciones permanentes para Claude Code… la biblia de producción del agente", v0.2 jun-2026. Define stack, documentos canónicos y jerarquía de autoridad ("PRD en producto → ADR en técnica → Agustín arbitra"). Ver Hallazgos H7/H8: ubicación y contenido desactualizados.
- **`docs/` canónicos**: `TakeOS_PRD_V3_6.md` (112 KB), `TakeOS_ADR_Backend_v1_10.md` (76 KB), `TakeOS_Arquitectura_y_Flujo_de_Trabajo_v1_6.md` (75 KB), `TakeOS_Roadmap_Operativo_v1_8.md` (47 KB), `TakeOS_Seguridad_OWASP_Top_10_2025_v1_3.md` (46 KB), `CHANGELOG.md` (421 líneas, al día: V11.31.0 — 30-jun-2026).
- **`docs/Planes/`** (5 archivos): planes de la modularización (`Plan_Modularizacion_Vite.md`, `PENDIENTES_Migracion_Vite.md` — deuda documentada: 404 de producción, cutover pendiente —, `HANDOFF_Code_PlanG_cablear_backend.md`, `RESUMEN_Sesion_Modularizacion.md`).
- **Cabeceras de archivo: 40/40** (`head -1` de cada .js): todos abren con comentario que declara *qué es* + *era de extracción*, p.ej. `// DAL — Capa de Acceso a Datos Supabase — extraído de index.html (Etapa B1)` (dal.js:1), `// Plan de Rodaje + Hoja de Llamado — extraído de index.html (Etapa A2)` (plan-rodaje.js:1). Única cabecera indirecta: presupuesto-cotizacion.js:1 (línea decorativa; el título va en la línea 2: `// MOD PRESUPUESTO + COTIZACIÓN — Etapa 2 de modularización con Vite`).

---

## Hallazgos

**H1 · Botón muerto por handler inline superviviente (bug funcional probable).** `modules/gastos.js:1558` emite HTML con `onclick='goDescargarXlsx(${…})'` — el único `on*=` en HTML generado de todo src. La CSP de `index.html:35` (`script-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com`, **sin `'unsafe-inline'`**) bloquea ese atributo; y aunque no lo hiciera, `goDescargarXlsx` es local del módulo (gastos.js:1565, no está en window). El botón "⬇ Descargar .xlsx" del export Chipax no puede funcionar.

**H2 · TDZ latente en state.js.** `lib/state.js:54`: `export let USUARIO_ACTUAL = ('USUARIO_ACTUAL' in window) ? USUARIO_ACTUAL : '';` — si algún día existe `window.USUARIO_ACTUAL` antes del eval del módulo, el brazo verdadero lee el **propio binding en TDZ** (quería ser `window.USUARIO_ACTUAL`) y lanza ReferenceError. Hoy nunca se cumple la condición, por eso no explota.

**H3 · Residuo D3a en rates.js.** `lib/rates.js:18-22`: `function _espejo() {\n\n\n}` — función vacía (el espejo window se apagó) que sigue llamándose en rates.js:22 y :48. Código muerto trivial pero delator de la purga a medias.

**H4 · Comentario-contrato falso en state.js.** El bloque `lib/state.js:228-230` promete que los setters "Actualizan el binding vivo … **Y el espejo window**", pero ningún setter (state.js:231-246) escribe window desde la purga D4c. Quien confíe en `window.ORG_ID` tras `setOrgId(v)` leerá un valor viejo o `undefined`.

**H5 · 48 bridges window sin ningún lector** (§3.3) más 3 `define()` huérfanos (§3.2) y 20 `export` sin importador (§3.1): cosecha final pendiente del desacople; superficie que invita a reintroducir acoplamientos por window.

**H6 · Comentario PENDIENTE desactualizado.** `lib/ui.js:783-784` afirma "regionSelectHTML/bancoSelectHTML aún emiten opts.onchange inline", pero ambas firmas actuales (`export function regionSelectHTML(current, opts)` ui.js:348; `export function bancoSelectHTML(current, opts)` ui.js:363) ya emiten `opts.accion` (data-accion, ver llamador bd.js:979 con `accionHTML('bd.pfBanco', { on: 'change' })`). La deuda descrita ya se pagó; el cartel quedó.

**H7 · CLAUDE.md fuera de su sitio declarado.** `docs/CLAUDE.md:3` dice "Vive en la raíz del proyecto; Claude Code lo lee solo al iniciar cada sesión" — pero está en `docs/`, donde el agente NO lo carga automáticamente. En la raíz no hay CLAUDE.md.

**H8 · CLAUDE.md contradice el estado real del repo.** Afirma "En producción corre el monolito… la modularización está EN CURSO… Etapas 0 y 1 hechas… ~88% del trabajo sigue pendiente" y "Patrón: cada función movida se puentea a window para no romper los onclick inline", cuando el repo está en D4c cerrado (commit 5e1d621: "window 962→73 (−92%)"), con CSP sin unsafe-inline y 0 `on*=` en index.html (`grep -coE ' on(click|…)="' index.html` → 0). También referencia `TakeOS_ADR_Backend_v1_9.md` cuando el archivo existente es `v1_10`.

**H9 · Cero red de seguridad async global** (§2.2): 35 fire-and-forget + 12 `.then` sin `.catch` + ausencia de `unhandledrejection`, con el agravante del patrón `try { fnAsync(); } catch {}` que aparenta protección sin darla (config.js:243-244,1062; notificaciones.js:120,162).

**H10 · Cero infraestructura de pruebas/lint/typecheck/hooks** (§5) en un frontend de 25 KLOC cuyos invariantes (364 acciones simétricas, 105/105 ganchos definidos, orden de imports de main.js:15 "⚠ antes de gastos.js") hoy solo se verifican a mano; las "compuertas" que los validaron viven en mensajes de commit, no en el repo.

**H11 · `_clientUuid` duplicado.** Dos implementaciones homónimas: `export function _clientUuid()` (lib/modelo.js:237, importada por dal.js:18) y `function _clientUuid()` privada (presupuesto-cotizacion.js:1337); ambas se publican en window (modelo.js:424 y presupuesto-cotizacion.js:4335) — la segunda pisa a la primera según orden de eval, sin lector conocido de `window._clientUuid`.