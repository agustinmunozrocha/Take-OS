Everything is measured and cross-validated. Here is the canonical census.

---

# Apéndice normativo — Censo canónico de mecanismos de intercomunicación

**Ámbito:** `/home/juandlc/Trabajo/Take-OS/frontend/src` — 40 archivos `.js`, 25.327 líneas (`wc -l $(find . -name "*.js")`), más `frontend/index.html` (1.556 líneas) solo para referencias `data-accion`.
**Commit de medición:** `4c8067b` (HEAD de `etapa4-integracion`). Toda cifra de este apéndice fue contada en este commit; **cualquier otra cifra del informe que difiera queda superseded por esta tabla.**

## 0. Metodología (tres capas)

Cada métrica se reporta en tres capas, siempre con este significado:

- **(a) crudo**: coincidencia literal de substring sobre el fuente completo (`grep -rno "<token>" --include="*.js"` para ocurrencias; sin `-o` para líneas).
- **(b) sin comentarios**: ocurrencias tras enmascarar comentarios `//` y `/* */` con un lexer JS carácter-a-carácter (strings intactos).
- **(c) call-sites ejecutables**: ocurrencias `\b<token>\(` sobre la capa de **solo código** (comentarios Y strings enmascarados; el código dentro de interpolaciones `${…}` de template literals se conserva como ejecutable, crítico porque casi todo `accionHTML(` vive dentro de `${…}`), excluyendo las declaraciones del mecanismo en `lib/ganchos.js` / `lib/delegacion.js`.

Lexer y censo: `/tmp/claude-1000/-home-juandlc-Trabajo-Take-OS/a12c6599-d353-4fef-bc18-5f957fa0b453/scratchpad/censo_canonico.py` (ganchos + window), `censo_acciones_can.py` (acciones). **Validación de cierre:** para los 4 tokens se verificó la identidad `a = b + ocurrencias-en-comentarios` con 0 ocurrencias en strings (`define(`: 112=109+3; `gancho(`: 195=186+9; `valor(`: 9=5+4; `window.`: 199=159+40), enumerando cada hit de comentario con su `archivo:línea` (p.ej. los 3 de `define(` son `lib/ganchos.js:8`, `:10`, `:12`).

## 1. Ganchos — `define(` / `gancho(` / `valor(`

Mecanismo: `lib/ganchos.js` — firmas reales:

```js
export function define(nombre, fn) {      // ganchos.js:18
export function gancho(nombre) {           // ganchos.js:23
export function valor(nombre) {            // ganchos.js:31
```

| token | (a) crudo (ocurrencias) | (a) crudo (líneas) | (b) sin comentarios | (c) call-sites | delta explicado |
|---|---|---|---|---|---|
| `define(` | **112** | 112 | **109** | **108** | a−b = 3 comentarios (todos en `ganchos.js:8,10,12`); b−c = 1 (la declaración `ganchos.js:18`) |
| `gancho(` | **195** | 171 | **186** | **185** | a−b = 9 comentarios (`ganchos.js:9`, `ui.js:680`×2, `presupuesto-cotizacion.js:10,11,1114,3723,3724`, `locaciones.js:798`); b−c = 1 (`ganchos.js:23`) |
| `valor(` | **9** | 9 | **5** | **4** | a−b = 4 comentarios (`nav.js:194`, `ganchos.js:10`, `boot.js:581`, `presupuesto-cotizacion.js:3723`); b−c = 1 (`ganchos.js:31`) |

Comandos: (a) `grep -rno "gancho(" --include="*.js" .` etc.; (b)/(c) `censo_canonico.py`.

**Nombres únicos** (capa c; los nombres son strings, extraídos del fuente en la posición del call-site; 0 call-sites con primer argumento no-literal):

- `define`: **108 nombres únicos en 108 call-sites** → *invariante: cada nombre se define exactamente una vez* (además `ganchos.js:19` avisa redefiniciones en runtime).
- `gancho`: **102 nombres únicos** en 185 call-sites.
- `valor`: **3 nombres únicos** en 4 call-sites: `MODULES` (`lib/ui.js:511`), `ESPACIO_DEMO` (`lib/boot.js:586`), `_orgLogos` (`presupuesto-cotizacion.js:3812` y `:4141`).
- Unión consumidos (`gancho` ∪ `valor`): **105 nombres** — coincide con la compuerta "105/105 OK" del commit `4c8067b`.
- **Consumidos sin `define`: 0.** (Invariante de la compuerta 2 satisfecho.)
- **Definidos sin consumidor: 3** — `_setOrgActiva` (`lib/boot.js:730`), `_pdCookiesBootCheck` (`modules/config.js:2164`), `goSavePresup` (`modules/gastos.js:1694`).

Top consumidores (capa c): `presupuesto-cotizacion.js` 44 `gancho(` + 2 `valor(`, `boot.js` 21+1, `dal.js` 20, `ui.js` 18+1, `nav.js` 17, `locaciones.js` 17. Productores top de `define(`: `boot.js` 10, `bd-excel.js` 10, `config.js` 10, `plan-rodaje.js` 9.

## 2. `window.`

| métrica | valor | comando/fuente |
|---|---|---|
| (a) ocurrencias crudas | **199** | `grep -rno "window\." --include="*.js" . \| wc -l` |
| (a) líneas crudas | **184** | ídem sin `-o` |
| (b) sin comentarios | **159** | lexer (a−b = 40 hits en comentarios, listados; 0 en strings) |
| (c) ejecutables | **159** | idéntico a (b) porque no hay `window.` dentro de strings |
| Propiedades distintas (capa c) | **84** | regex `\bwindow\.([A-Za-z_$][\w$]*)` sobre capa código |
| — nativas del navegador | 14 props / 74 ocurrencias | `location`(20), `open`(10), `localStorage`(8), `prompt`(8), `scrollTo`(6), `innerWidth`(5), `confirm`(4), `crypto`(4), `addEventListener`(3), `innerHeight`(2), `scrollX/Y`(1+1), `removeEventListener`(1), `getSelection`(1) |
| — vendor CDN (solo lectura) | 2 props / 8 ocurrencias | `XLSX`(4), `ExcelJS`(4) — cargados por `<script src>` en `index.html:1282,1284` |
| — propias de la app | **68 props / 77 ocurrencias** | resto |
| Asignaciones `window.X =` (capa c) | **73** sobre **68 props distintas** | regex de asignación (`=` no seguido de `=`, más compuestos) — coincide con "window 962→73" del merge `5e1d621` |
| `window[expr]` computado | **0** | regex `\bwindow\[` capa código |

**Invariantes derivados:** (i) las 68 props propias asignadas = exactamente las 68 props propias referenciadas → *ninguna prop propia se lee sin ser asignada en src* (cero lecturas fantasma); (ii) **65 de 68 props propias son solo-escritura** (espejo/export sin lector interno — API legada expuesta a consola/exterior); las únicas 3 con lecturas internas son `_ORG_EPOCA` (1 lectura), `__TAKEOS_USER` (1), `_persisResetOrg` (2). Sitios de asignación completos con `archivo:línea` en la salida de `censo_canonico.py` (p.ej. `lib/state.js:226 STATE`, `modules/dal.js:244 __TAKEOS_DATA_SOURCE`).

## 3. Acciones — `registrarAcciones` / `accionHTML` / `data-accion`

Mecanismo: `lib/delegacion.js` — firmas reales:

```js
export function registrarAcciones(ns, mapa) {   // delegacion.js:16
export function accionHTML(accion) {             // delegacion.js:24
```

**`registrarAcciones`:** (a) 27 líneas crudas (`grep -rn "registrarAcciones(" --include="*.js" . | wc -l`) = 25 llamadas + declaración `delegacion.js:16` + comentario `delegacion.js:4`; (b) 26; **(c) 25 call-sites** — los 25 con `ns` literal, en: `boot.js:699` (`boot`), `boot.js:705` (`app`), `ui.js:785` (`ui`), y 22 en módulos, con `presupuesto-cotizacion.js:4444` **y** `:4471` registrando ambos el ns `pre` (fusión vía `Object.assign` en `delegacion.js:17`). → **25 llamadas, 24 namespaces.**

**Acciones registradas** (parseo balanceado de llaves sobre la capa código de cada objeto `mapa`, claves top-level; 0 claves duplicadas dentro de un ns — el script las habría reportado): **364 acciones en 24 namespaces**:

| ns | # | ns | # | ns | # | ns | # |
|---|---|---|---|---|---|---|---|
| `go` | 50 | `bd` | 40 | `loc` | 37 | `ntf` | 32 |
| `lgl` | 27 | `pre` | 23 | `calc` | 17 | `tm` | 16 |
| `app` | 15 | `cfg` | 14 | `cargo` | 13 | `info` | 13 |
| `ui` | 11 | `esp` | 11 | `crew` | 10 | `pr` | 9 |
| `doc` | 7 | `kanban` | 6 | `inv` | 4 | `rodajes` | 4 |
| `snap` | 2 | `boot` | 1 | `buscador` | 1 | `plan` | 1 |

**`accionHTML`:** (a) 376 (`grep -rno "accionHTML(" ... | wc -l`); (b) 374 (−2 comentarios `delegacion.js:21,22`); **(c) 373 call-sites** (−1 declaración `delegacion.js:24`), **todos con primer argumento string literal** (0 dinámicos).

**Acciones referenciadas** (tres fuentes, excluyendo `lib/delegacion.js` — su `'data-accion="' + accion + '"'` en `delegacion.js:29` es la maquinaria, no una referencia):

| fuente | ocurrencias | comando |
|---|---|---|
| 1er arg literal de `accionHTML(` (capa c) | **373** | `censo_acciones_can.py` |
| `data-accion="…"` literal dentro de strings JS (capa strings del lexer) | **424** | ídem |
| `data-accion="…"` en `frontend/index.html` estático | **31** (15 distintas, todas ns `app`; `app.modulo` ×16) | `grep -c 'data-accion=' frontend/index.html` |
| **Total** | **828 ocurrencias / 364 acciones distintas** | |

**Invariante central (biyección exacta):** conjunto registrado ≡ conjunto referenciado, 364 = 364; **0 registradas sin referencia y 0 referenciadas sin registro**. Todas las referencias son estáticas: no existe `data-accion` con namespace o nombre interpolado (`${…}`) en todo src.

⚠️ Nota anti-confusión: **364 acciones = 364 aristas import es coincidencia numérica**, no una relación.

## 4. Grafo de imports

- **(a) 365 declaraciones `import`** (`grep -rnE "^\s*import\s" --include="*.js" . | wc -l`); las 365 son estáticas — **0 `import()` dinámicos, 0 re-exports `export … from`** (greps con 0 hits). Ninguna en comentario/string; no hay dos imports en una línea.
- **364 aristas únicas (origen→destino)** tras resolver especificadores relativos. **Único duplicado, verificado:** `modules/presupuesto-cotizacion.js:6` (`import { STATE, TAKEOS_PERFIL } from '../lib/state.js';`) y `:12` (`import { BD_PERSONAS, EMPRESA_PERFIL, STATES_WITH_LOCKED_BUDGET, STATES_WITH_REAL_COST } from '../lib/state.js';`) — misma arista `presupuesto-cotizacion.js → lib/state.js` en dos declaraciones. 365 − 1 = 364 ✓.
- Por zonas: `modules→lib` 189, `modules→modules` 101, `lib→lib` 31, `main.js→modules` 25, `main.js→lib` 11, `lib→modules` **7** (las 7 desde `lib/boot.js`, hacia `buscador`, `dal`, `gastos`, `info-proyecto`, `kanban`, `notificaciones`, `persistencia-local`). 189+101+31+25+11+7 = 364 ✓.

## 5. Aristas invertidas (runtime, vía ganchos) — reconciliación 57 / 44 / 27

Definición operativa: para cada nombre, arista **C ~> P** donde C = archivo que lo consume (`gancho(`/`valor(`) y P = el único archivo que lo `define(`. Se cuentan **pares únicos (C,P) con C≠P**. Datos: `censo_nombres.json` + `import_edges.json`.

- **Efectivas: 57** pares únicos (105 nombres los atraviesan; **0 autoconsumo** C=P, **0 nombres huérfanos**).
- **Con import reverso: 44** — pares donde además existe la arista estática `P → C` (el productor importa al consumidor; la inversión de dependencia es real: sin gancho habría ciclo ESM).
- **lib ~> modules: 27** — pares con C∈`lib/`, P∈`modules/`.

**Las dos categorías se SOLAPAN — no son partición de 57.** Tabla de verdad completa:

| import reverso | lib~>modules | pares |
|---|---|---|
| sí | sí | **20** |
| sí | no | 24 |
| no | sí | 7 |
| no | no | 6 |

Suma: 20+24+7+6 = 57 ✓; "44" = 20+24; "27" = 20+7. Es decir: **44 + 27 − 20 (solape) + 6 (ninguna) = 57.** Los 57 por zonas: lib~>modules 27, modules~>modules 23, modules~>lib 5, lib~>lib 2.

Los 6 pares "ni reverso ni lib~>modules" (ganchos que hoy no invierten ningún import existente): `persistencia-local~>admin`, `presupuesto-cotizacion~>{lib/boot, legal, tareas}`, `tareas~>lib/boot`, `config~>persistencia-local`. Además, **5 pares tienen también la arista estática directa C→P** (`bd~>bd-excel`, `config~>admin`, `kanban~>persistencia-local`, `locaciones~>bd`, `config~>persistencia-local`): en los 4 primeros coexiste con el import reverso → son **ciclos estáticos bidireccionales ya existentes** donde el gancho evita añadir presión de orden de evaluación.

## 6. Reconciliación de las cifras contradictorias del informe

| cifra reportada | veredicto |
|---|---|
| `gancho(`: **185** | = capa (c) canónica ✓ |
| `gancho(`: 194, 189, 170 | no corresponden a ninguna capa en HEAD (a=195/líneas=171/b=186/c=185) ni a ningún commit reciente del mainline (`git grep -o -F "gancho(" <commit>` da 188 en `03a95fd`, 157 en `d8058fd`, 195 desde `e2e9c5a`): cifras obsoletas o con criterio de exclusión no documentado — **descartar** |
| `valor(`: 4 / 5 / 7 | 4 = (c) ✓; 5 = (b); 7 = crudo excluyendo `ganchos.js` (9−2) — mediciones válidas de capas distintas; **canon: a=9, b=5, c=4** |
| `define(`: 108 / 110 / 112 | 108 = (c) ✓; 112 = (a) en HEAD; 110 = (a) en `03a95fd` y 111 en `5e1d621` (HEAD añadió `nav.js:194 define('MODULES'…)`) — deriva temporal; **canon: a=112, b=109, c=108** |
| `window.`: 184 / 194 / 199 | 184 = (a) líneas ✓; 199 = (a) ocurrencias ✓; 194 no corresponde a nada en HEAD ni en los 4 commits previos (líneas estables en 184) — **descartar**; **canon: a=199 occ/184 líneas, b=c=159** |
| imports: 365/364 | ✓ confirmado; duplicado = `presupuesto-cotizacion.js:6` y `:12` → `lib/state.js` |
| invertidas: 57/44/27 | ✓ las tres reproducidas; son conjuntos solapados (§5), no sumandos |

## Hallazgos

1. **Import duplicado** `modules/presupuesto-cotizacion.js:6` y `:12`, ambos de `'../lib/state.js'` — inocuo en ESM pero es la única arista con 2 declaraciones; consolidable.
2. **3 `define(` sin consumidor** (código muerto del lado gancho o API para futuro): `_setOrgActiva` (`lib/boot.js:730`), `_pdCookiesBootCheck` (`modules/config.js:2164`), `goSavePresup` (`modules/gastos.js:1694`). La compuerta actual verifica consumido→definido pero no definido→consumido.
3. **Publicación dual de `_orgLogos`**: `modules/config.js:2119` (`window._orgLogos = _orgLogos;`) **y** `:2171` (`define('_orgLogos', _orgLogos);`) — dos canales para el mismo símbolo; el consumidor interno usa `valor('_orgLogos')` (`presupuesto-cotizacion.js:3812,4141`), y en `:4141` además hace `typeof _orgLogos === 'function'` sobre un identificador que en ese módulo solo puede resolver al global implícito de `window._orgLogos` — acoplamiento residual al espejo window.
4. **`config.js ~> persistencia-local.js` vía gancho siendo que existe el import estático directo** `config.js → persistencia-local.js` y NO existe el reverso: el gancho no invierte nada ahí; los 2 nombres podrían ser imports normales (o el motivo anti-ciclo es transitivo y no está documentado).
5. **65 de 68 props `window` propias son solo-escritura** (asignadas, jamás leídas en src): superficie API legada expuesta al exterior sin contrato; candidatas a poda o a documento de API pública. Las 3 con lecturas internas (`_ORG_EPOCA`, `__TAKEOS_USER`, `_persisResetOrg`) son los últimos usos reales de window como bus interno.
6. **4 ciclos de import estáticos bidireccionales** entre módulos (`bd↔bd-excel`, `config↔admin`, `kanban↔persistencia-local`, `locaciones↔bd`), visibles porque sus pares gancho tienen a la vez arista directa y reversa — legales en ESM pero sensibles a TDZ si algún top-level toca bindings del otro.
7. **Trampa de medición documentada**: `grep -c` (líneas) vs `grep -o | wc -l` (ocurrencias) difieren para `gancho(` (171 vs 195) y `window.` (184 vs 199) por múltiples hits por línea; varias contradicciones del informe nacen de mezclar ambos sin declararlo.