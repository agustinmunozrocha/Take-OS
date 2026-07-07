# Grafo de dependencias ESM — `frontend/src/**/*.js` (Take-OS, rama `etapa4-integracion`, HEAD `4c8067b`)

**Metodología.** Script Python read-only (`grafo.py`) que parsea con regex todos los `import … from '…'` / `import '…'` / `export … from '…'` / `import('…')` (comentarios eliminados antes de matchear) sobre los 40 archivos (`find frontend/src -name "*.js" | wc -l` → 40), resuelve especificadores relativos a rutas reales y construye el grafo dirigido. Verificaciones finas (benignidad por timing, identificadores libres) hechas con AST real vía `rollup/dist/es/parseAst.js` (rollup 4.62.0, ya en `node_modules`). Cero imports dinámicos (`grep -rn "import(" frontend/src --include="*.js"` → 0 resultados en código; el único `import.` es `import.meta.env` en `lib/supabase.js:11-12`). Cero imports externos a src (0 especificadores npm/URL) — la superficie externa es: `import.meta.env.VITE_SUPABASE_URL/KEY` (`lib/supabase.js:11-12`), el UMD global `supabase` (`lib/supabase.js:20`) y vendors lazy (`XLSX`/`ExcelJS` vía `ensureXLSX`).

---

## 1. Métricas

- **Nodos:** 40 (14 `lib/`, 25 `modules/`, 1 `main.js`).
- **Aristas únicas archivo→archivo:** 364. Declaraciones `import`: 365 (1 duplicado, ver Hallazgos §7).
- **Grado medio de salida:** 364/40 = 9.1.
- **Cuadrantes:** `lib→lib` = 31 · `modules→lib` = 189 · `modules→modules` = 101 · `lib→modules` = 7 · `main→*` = 36. (31+189+101+7+36 = 364 ✓)

### Tabla completa de grados (ordenada por grado total desc.; contada por el script)

| archivo | out | in |
|---|---:|---:|
| main.js | 36 | 0 |
| lib/ui.js | 7 | 25 |
| modules/dal.js | 16 | 15 |
| lib/helpers.js | 0 | 30 |
| lib/state.js | 0 | 30 |
| modules/persistencia-local.js | 9 | 20 |
| lib/ganchos.js | 0 | 28 |
| modules/kanban.js | 13 | 13 |
| lib/delegacion.js | 1 | 24 |
| modules/bd.js | 17 | 7 |
| modules/config.js | 19 | 5 |
| lib/boot.js | 15 | 8 |
| modules/presupuesto-cotizacion.js | 10 | 12 |
| modules/locaciones.js | 16 | 5 |
| modules/gastos.js | 16 | 4 |
| modules/info-proyecto.js | 15 | 5 |
| lib/nav.js | 5 | 14 |
| modules/notificaciones.js | 12 | 6 |
| modules/plan-rodaje.js | 15 | 3 |
| modules/admin.js | 13 | 3 |
| modules/bd-excel.js | 9 | 7 |
| lib/data.js | 3 | 12 |
| lib/modelo.js | 3 | 12 |
| lib/supabase.js | 0 | 15 |
| modules/legal.js | 13 | 2 |
| lib/auth.js | 2 | 12 |
| lib/calc.js | 2 | 12 |
| modules/cargos.js | 13 | 1 |
| modules/buscador.js | 11 | 2 |
| modules/calculadoras.js | 12 | 1 |
| modules/espacio.js | 11 | 1 |
| modules/perfil-onboarding.js | 8 | 4 |
| modules/invitaciones.js | 7 | 4 |
| modules/tareas.js | 9 | 2 |
| modules/crew.js | 9 | 1 |
| modules/plan-limites.js | 4 | 6 |
| modules/documentos.js | 8 | 1 |
| modules/rodajes.js | 5 | 3 |
| lib/rates.js | 0 | 7 |
| lib/catalogos.js | 0 | 2 |

**Top 5 hubs de entrada (más importados):** `lib/helpers.js` (30), `lib/state.js` (30), `lib/ganchos.js` (28), `lib/ui.js` (25), `lib/delegacion.js` (24). El 6º es el primer módulo: `modules/persistencia-local.js` (20) — es de facto infraestructura (markDirty/autosave), no feature.

**Top 5 hubs de salida (más importadores):** `main.js` (36 — es el manifiesto de orden de eval), `modules/config.js` (19), `modules/bd.js` (17), `modules/dal.js` (16), `modules/gastos.js` (16) y `modules/locaciones.js` (16, empate).

`main.js` (50 líneas, `wc -l`) importa 36 de los 39 restantes; los 3 que le llegan solo transitivos son `lib/catalogos.js`, `lib/delegacion.js`, `lib/ganchos.js`.

---

## 2. Ciclos (Tarjan)

**Resultado: 1 SCC no trivial de 19 nodos con 88 aristas internas** (contadas por el script; sin autolazos). Miembros:

```
lib/boot.js, modules/{admin, bd-excel, bd, buscador, config, dal, gastos,
info-proyecto, invitaciones, kanban, legal, locaciones, notificaciones,
perfil-onboarding, persistencia-local, plan-rodaje, presupuesto-cotizacion, tareas}
```

Los otros 21 nodos son SCCs triviales (grafo acíclico fuera del núcleo). Dentro del SCC hay **9 ciclos de longitud 2** (imports mutuos, contados por `ciclos_v2.py`):

```
modules/admin.js        <-> modules/config.js
modules/bd-excel.js     <-> modules/bd.js
modules/bd.js           <-> modules/dal.js
modules/bd.js           <-> modules/locaciones.js
modules/dal.js          <-> modules/kanban.js
modules/dal.js          <-> modules/legal.js
modules/dal.js          <-> modules/locaciones.js
modules/dal.js          <-> modules/persistencia-local.js
modules/kanban.js       <-> modules/persistencia-local.js
```

Ejemplo de cadena mayor dentro del SCC: `lib/boot.js → modules/dal.js → modules/legal.js → modules/plan-rodaje.js → lib/boot.js` (aristas verificadas en la lista interna del SCC).

**Verificación de benignidad por timing (AST, `evaltime_scc2.mjs`):** para cada miembro del SCC se recolectaron los bindings importados desde otros miembros del SCC y se buscó todo uso en posición **eval-time** (fuera de cuerpos de función, descendiendo dentro de cuerpos de IIFE, que sí ejecutan al eval — 3 IIFEs top-level atravesadas). **Resultado: 0 usos eval-time.** Todos los usos cross-ciclo están dentro de funciones que corren post-arranque, así que con live bindings ESM ningún ciclo produce TDZ hoy. **Invariante implícito no vigilado estáticamente:** "ningún módulo del SCC usa un binding intra-SCC al eval". Una sola llamada top-level nueva lo rompe (ver Hallazgos §3).

---

## 3. Capas emergentes (profundidad topológica sobre el grafo condensado; hoja = 0)

| capa | n | archivos |
|---|---:|---|
| 0 (hojas puras) | 6 | `lib/catalogos.js`, `lib/ganchos.js`, `lib/helpers.js`, `lib/rates.js`, `lib/state.js`, `lib/supabase.js` |
| 1 | 3 | `lib/auth.js`, `lib/delegacion.js`, `lib/modelo.js` |
| 2 | 1 | `lib/data.js` |
| 3 | 2 | `lib/calc.js`, `lib/ui.js` |
| 4 | 3 | `lib/nav.js`, `modules/plan-limites.js`, `modules/rodajes.js` |
| 5 | 19 | **el SCC completo** (boot + 18 módulos) |
| 6 | 5 | `modules/calculadoras.js`, `modules/cargos.js`, `modules/crew.js`, `modules/documentos.js`, `modules/espacio.js` |
| 7 | 1 | `main.js` |

Lectura: **todas las hojas puras son `lib/`** (los dueños de estado `state.js`/`rates.js`, el bus `ganchos.js`, el cliente `supabase.js`, utilidades `helpers.js`, catálogos). `lib/` ocupa íntegro capas 0–4 (salvo `boot.js`, arrastrado a capa 5 por el SCC) y `modules/` se estratifica encima: 2 módulos "bajos" que solo consumen lib (`plan-limites`, `rodajes`, capa 4), la maraña de 19 en capa 5, y 5 módulos "altos" que consumen a la maraña sin ser consumidos por import (capa 6, solo alcanzables vía ganchos/delegación). Estratificación limpia con una sola anomalía: `lib/boot.js`.

---

## 4. Frontera lib/ vs modules/

**`lib/` importando `modules/`: 7 aristas, todas desde un único archivo, `lib/boot.js`** (`frontend/src/lib/boot.js:14-23`):

```
lib/boot.js -> modules/kanban.js, modules/notificaciones.js, modules/persistencia-local.js,
               modules/dal.js, modules/gastos.js, modules/buscador.js, modules/info-proyecto.js
```

Es deliberado y está documentado en su cabecera (`lib/boot.js:5-8`): es el orquestador de arranque ("la mitad IMPORT del ciclo duro boot⇄dal (down-call del orquestador). DIFERIDOS anti-ciclo: config, espacio, invitaciones, perfil-onboarding"). El resto de `lib/` (13/14 archivos) **jamás importa de modules/**: habla hacia arriba solo por ganchos (27 aristas invertidas, §5). Ver Hallazgos §6 sobre la ubicación de boot.

**Aristas `modules→modules`: 101** (lista completa, agrupada por origen; los conteos suman 101):

| origen | destinos (out intra-modules) |
|---|---|
| admin (5) | config, dal, info-proyecto, kanban, presupuesto-cotizacion |
| bd-excel (4) | bd, dal, persistencia-local, presupuesto-cotizacion |
| bd (7) | bd-excel, dal, gastos, kanban, locaciones, persistencia-local, presupuesto-cotizacion |
| buscador (6) | admin, bd, config, gastos, kanban, persistencia-local |
| calculadoras (3) | info-proyecto, persistencia-local, presupuesto-cotizacion |
| cargos (7) | bd-excel, config, dal, info-proyecto, invitaciones, persistencia-local, plan-limites |
| config (10) | admin, bd, dal, invitaciones, kanban, notificaciones, perfil-onboarding, persistencia-local, plan-limites, presupuesto-cotizacion |
| crew (3) | bd, persistencia-local, plan-rodaje |
| dal (7) | bd, kanban, legal, locaciones, persistencia-local, plan-limites, presupuesto-cotizacion |
| documentos (2) | dal, persistencia-local |
| espacio (5) | config, invitaciones, kanban, perfil-onboarding, plan-limites |
| gastos (7) | bd-excel, dal, kanban, notificaciones, persistencia-local, plan-limites, presupuesto-cotizacion |
| info-proyecto (5) | bd-excel, dal, kanban, persistencia-local, presupuesto-cotizacion |
| invitaciones (1) | perfil-onboarding |
| kanban (3) | dal, persistencia-local, presupuesto-cotizacion |
| legal (6) | bd-excel, dal, locaciones, notificaciones, persistencia-local, plan-rodaje |
| locaciones (6) | bd-excel, bd, dal, persistencia-local, presupuesto-cotizacion, rodajes |
| notificaciones (2) | kanban, persistencia-local |
| perfil-onboarding (1) | dal |
| persistencia-local (2) | dal, kanban |
| plan-rodaje (6) | locaciones, notificaciones, persistencia-local, presupuesto-cotizacion, rodajes, tareas |
| presupuesto-cotizacion (1) | persistencia-local |
| tareas (2) | kanban, persistencia-local |

Sumideros intra-modules: `persistencia-local` (recibe de 18 de los 24 módulos restantes), `dal` (12), `kanban` (10), `presupuesto-cotizacion` (10).

---

## 5. Aristas invertidas (ganchos)

Contrato del bus (`lib/ganchos.js:18-33`, firmas reales):

```js
export function define(nombre, fn) {
export function gancho(nombre) {   // devuelve wrapper; si no está definido: console.error('[ganchos] sin definir:', nombre) y return undefined
export function valor(nombre) {
```

Invariante documentado en su cabecera (`lib/ganchos.js:12-14`): "Todos los define() corren al EVAL del productor (antes de DOMContentLoaded); toda invocación es runtime post-arranque — nunca hay carrera."

**Conteos** (regex `\bgancho\(\s*['"]…` / `\bvalor\(` / `\bdefine\(` sobre código sin comentarios, script `grafo.py`): **185 llamadas `gancho(`, 4 `valor(`, 108 `define(`**; nombres únicos: 102 gancho / 3 valor / 108 define. Consumidores principales: `presupuesto-cotizacion` (44+2), `boot` (21+1), `dal` (20), `ui` (18+1), `nav` (17), `locaciones` (17), `tareas` (14), `kanban` (12). Productores principales (`define`): `bd-excel` (10), `boot` (10), `config` (10), `plan-rodaje` (9), `tareas` (8), `espacio` (7).

Colapsando por par (consumidor→definidor del mismo nombre): **57 aristas invertidas efectivas**, contra 364 aristas import → **13.5 % de las 421 dependencias dirigidas totales van por inversión de control**. De esas 57:

- **44 tienen el import reverso ya existente** — inversión real de ciclo potencial: si fueran imports, añadirían 44 aristas antiparalelas al grafo (p.ej. `lib/nav.js ~~> modules/kanban.js` con `kanban → nav` ya import; `lib/ui.js ~~> lib/nav.js` con `nav → ui` ya import).
- **27 son `lib ~~> modules`** — dependencias lib→módulo evitadas. Distribución: `lib/nav.js` 13 (todos los `render*` de módulo: `renderBDPersonas`, `renderCargos`, `renderCrew`, `renderDocumentos`, `renderInfoProyecto`, `renderLegal`, `renderLocaciones`, `renderNotificaciones`, `renderHojaLlamado`, `renderPlanRodaje`, `renderCotizacion`, `renderPresupuesto`, `refreshSidebarTaskCounters`, `_lastViewSave`), `lib/ui.js` 7, `lib/boot.js` 4 (`config`, `espacio`, `invitaciones`, `perfil-onboarding` — exactamente los 4 "DIFERIDOS anti-ciclo" de su cabecera), `lib/calc.js` 2, `lib/modelo.js` 2.

Patrón nítido: `nav.js` es un **dispatcher por ganchos** (registro `export const MODULES = {` en `lib/nav.js:48`, `export function navigateToModule(moduleKey) {` en `lib/nav.js:13`); los módulos de capa 6 (calculadoras, cargos, crew, documentos, espacio) **solo publican por define()** — nadie los importa salvo main.js.

**Nombres sin consumidor (defines huérfanos, 3):** `'_setOrgActiva'` (`lib/boot.js:730`), `'goSavePresup'` (`modules/gastos.js:1694`), `'_pdCookiesBootCheck'` (`modules/config.js:2164`). Consumidos sin define: **0** (la compuerta del commit `4c8067b` se cumple). El tercero de esos huérfanos es síntoma de un bug real — Hallazgos §2.

---

## 6. Diagrama por capas (completo; `→ [imports]`, `~~>` = ganchos destacados)

```
capa 0 (hojas): catalogos · ganchos · helpers · rates · state · supabase          [todo lib/]
capa 1: auth → [helpers, state] · delegacion → [helpers] · modelo → [catalogos, ganchos, state]
capa 2: data → [catalogos, modelo, rates]
capa 3: calc → [data, ganchos] (~~> gastos, presupuesto-cotizacion)
        ui → [auth, data, delegacion, ganchos, helpers, modelo, state] (~~> nav, bd, bd-excel, dal, perfil-onb, persist-local, tareas)
capa 4: nav → [auth, ganchos, helpers, state, ui] (~~> 13 render* de módulos + boot)
        plan-limites → [delegacion, helpers, supabase, ui]
        rodajes → [delegacion, ganchos, helpers, state, ui]
capa 5 — SCC[19] (88 aristas internas; colapsado, aristas hacia abajo):
        boot → [auth, delegacion, ganchos, nav, rates, state, supabase, ui | buscador, dal, gastos,
                info-proyecto, kanban, notificaciones, persistencia-local]      ← ÚNICO lib→modules
        dal → [auth, calc, data, ganchos, helpers, modelo, nav, state, ui | bd, kanban, legal,
               locaciones, persistencia-local, plan-limites, presupuesto-cotizacion]
        bd → [10 lib | bd-excel, dal, gastos, kanban, locaciones, persist-local, presupuesto-cot]
        config → [9 lib(incl. boot) | admin, bd, dal, invitaciones, kanban, notificaciones,
                  perfil-onboarding, persist-local, plan-limites, presupuesto-cot]
        kanban ⇄ dal ⇄ persistencia-local ⇄ kanban  (triángulo denso de infraestructura)
        gastos, info-proyecto, legal, locaciones, plan-rodaje, presupuesto-cotizacion,
        notificaciones, tareas, bd-excel, buscador, admin, invitaciones, perfil-onboarding
        (aristas exactas: tabla §4 + 9 pares mutuos §2)
capa 6: calculadoras → [7 lib | info-proyecto, persist-local, presupuesto-cot]
        cargos → [6 lib | bd-excel, config, dal, info-proyecto, invitaciones, persist-local, plan-limites]
        crew → [5 lib + boot | bd, persist-local, plan-rodaje]
        documentos → [5 lib + supabase | dal, persist-local]
        espacio → [5 lib + boot | config, invitaciones, kanban, perfil-onb, plan-limites]
        (los 5 publican su API solo vía define(); in-degree por import = 1, solo main.js)
capa 7: main.js → [36 side-effect imports en orden fijo; comentario de orden en main.js:14:
        "nav.js ⚠ antes de gastos.js"]
```

---

## Hallazgos

1. **CRÍTICO (bug funcional): `ReferenceError` al abrir el detalle de una locación.** `frontend/src/modules/locaciones.js:318` (dentro de `export function openLocDetail(locId) {`, `locaciones.js:239`) evalúa `${_bdPuedeArchivar() ? …}` en un template literal, pero `_bdPuedeArchivar` es **file-local y no exportada** en `frontend/src/modules/bd.js:695` (`function _bdPuedeArchivar() { return !!(STATE.adminMode && authNivel('eliminar_proyecto') === 'E'); }`), no está importada por locaciones.js, no tiene espejo `window._bdPuedeArchivar` (grep → 0) ni define de gancho. En strict mode (ESM) el identificador libre lanza `ReferenceError` en cada llamada a `openLocDetail` (llamada desde ≥8 sitios: `locaciones.js:322,324,326,404,421,450,547,554`). El espejo `window._bdPuedeArchivar` se retiró en el commit `e2e9c5a` ("espejos apagados (27/27 props sin lector)", `git log -S 'window._bdPuedeArchivar'`) — la compuerta de "sin lector" no vio este lector dentro de template literal.

2. **ALTO (bug enmascarado): el check de cookies del boot nunca corre.** `frontend/src/lib/boot.js:578` cierra la cadena post-DAL con `try { setTimeout(_pdCookiesBootCheck, 1200); } catch (e) {}` — `_pdCookiesBootCheck` es identificador libre en boot.js (no importado, no local; la función real es `export async function _pdCookiesBootCheck() {` en `frontend/src/modules/config.js:2060`). El `ReferenceError` lo traga el try/catch: silencio total. El espejo window se retiró en `df64f69` (d4a). Nótese que la llamada vecina en la misma línea sí usa el patrón correcto (`gancho('_cpTourInicialQuizas')()`), y que el `define('_pdCookiesBootCheck', …)` de `config.js:2164` existe pero es huérfano (0 consumidores gancho) — es exactamente la mitad que quedó sin conectar. El flujo de `espacio.js:348` sí lo importa y funciona.

3. **SCC de 19 módulos (48 % de los nodos, 88 aristas internas).** Benigno por timing hoy (0 usos eval-time verificados por AST, incl. IIFEs), pero el invariante "ningún binding intra-SCC se usa al eval" no tiene compuerta estática; cualquier llamada top-level nueva dentro del ciclo puede producir TDZ dependiente del orden DFS de `main.js`. El script `evaltime_scc2.mjs` de este análisis es reutilizable como gate de CI.

4. **Las guardas `typeof X === 'function'` dependen de los 73 espejos `window.X=` restantes.** 11 sitios leen identificadores bare que hoy solo existen como `window.*`: `lib/ui.js:162` (`crewAddToBD` ← `bd.js:1126`), `ui.js:163` (`openPersonaForm` ← `bd.js:1128`), `ui.js:353` (`_regionCanonica` ← `perfil-onboarding.js:602`), `ui.js:362` (`_codigoBancoSBIF` ← `bd-excel.js:745`), `lib/modelo.js:23,28`, `modules/presupuesto-cotizacion.js:740,1116,1117,3905,4141` (`goLineaTieneCaja`, `renderGastos`, `renderHojaLlamado`, `legalRep`, `_orgLogos`). Si la purga de window continúa (dirección declarada del proyecto: 962→73), estas guardas pasan a always-false y **matan silenciosamente el gancho que custodian** — el mismo mecanismo que produjo §1 y §2. Las guardas son además redundantes: `gancho()` ya reporta en consola el nombre faltante sin lanzar. (Conteo: `grep -rEon "window\.[A-Za-z_$]+\s*=[^=]" src --include='*.js' | wc -l` → 73, coherente con el commit `5e1d621` "window 962→73".)

5. **`sb` en modo dual.** `lib/supabase.js:15-16`: `export let sb = null;` + `if (!('sb' in window)) window.sb = null;`. 13 archivos lo importan como binding vivo (`grep -rln "import.*{[^}]*\bsb\b[^}]*}.*supabase"`), pero 7 lo leen como global bare vía `window.sb` (detectado por el escáner de identificadores libres): `lib/boot.js:92`, `lib/rates.js:25`, `lib/ui.js:440`, `modules/bd.js:705`, `modules/config.js:269`, `modules/dal.js:35`, `modules/gastos.js:452`. Funciona (supabaseInit sincroniza ambos en `supabase.js:21-22`) y el comentario de la línea 16 muestra que es deliberado, pero son dos mecanismos de resolución para el mismo recurso y el modo bare es invisible al grafo de imports.

6. **`DAL_SESSION_UID`/`DAL_SESSION_EMAIL` son estado sin dueño ESM.** Nacen como props de window en `lib/state.js:52-53` (`window.DAL_SESSION_UID = null;`) y se escriben por identificador bare en `modules/dal.js:482-483` (`DAL_SESSION_UID = sess.user.id || null;`) — funciona solo porque la prop existe en window (si no, sería `ReferenceError` en strict mode). Está fuera del patrón `export let` + setter que usa el resto de `state.js` (p.ej. `state.js:40` `export let ORG_ID = …`).

7. **Import duplicado:** `modules/presupuesto-cotizacion.js:6` (`import { STATE, TAKEOS_PERFIL } from '../lib/state.js';`) y `:12` (`import { BD_PERSONAS, EMPRESA_PERFIL, STATES_WITH_LOCKED_BUDGET, STATES_WITH_REAL_COST } from '../lib/state.js';`). Benigno, pero rompe la unicidad arista↔declaración.

8. **`lib/boot.js` es la única violación de la frontera lib→modules (7 aristas)** y el único `lib/` dentro del SCC. Está documentado como orquestador (`boot.js:5-8`), pero su ubicación en `lib/` hace que la regla "lib no importa modules" no sea afirmable como invariante mecánico; movido a `src/` raíz o `modules/`, la frontera quedaría en 0 y verificable por compuerta. Además su cabecera está desactualizada: `boot.js:7-8` dice de los diferidos anti-ciclo "sus símbolos siguen vía window", pero desde d4b van vía ganchos (`lib/boot.js ~~> config/espacio/invitaciones/perfil-onboarding`, 14 nombres).

9. **Defines huérfanos (2 restantes tras descontar §2):** `'_setOrgActiva'` (`lib/boot.js:730`; la función se usa localmente en `boot.js:626`, el define no tiene consumidor) y `'goSavePresup'` (`modules/gastos.js:1694`; ídem, uso local en `gastos.js:1647`). Ruido en el registro del bus; la compuerta actual (todo consumo tiene define) no cubre la dirección inversa.

10. **`window.logoutTakeOS`/`window.confirmLogout`** (`lib/boot.js:91,97`) se definen como props de window y se invocan bare en el mismo archivo (`boot.js:104,719`) — funcionan, pero son dos de los 73 espejos restantes que podrían ser `function` locales sin window.

Scripts del análisis (reproducibles, read-only): `/tmp/claude-1000/-home-juandlc-Trabajo-Take-OS/a12c6599-d353-4fef-bc18-5f957fa0b453/scratchpad/{grafo.py, ciclos_v2.py, evaltime_scc2.mjs, libres.mjs}`.