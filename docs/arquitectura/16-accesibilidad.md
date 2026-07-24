# Auditoría de accesibilidad — Rizora `frontend/` (solo lectura)

## 0. Línea base cuantitativa

Cifras contadas sobre `/home/juandlc/Trabajo/Take-OS/frontend` (src/ + index.html), comando entre paréntesis:

| Métrica | Valor | Comando |
|---|---|---|
| Usos de `aria-*` en toda la app | **4** | (`grep -rn "aria-" src index.html`) |
| Usos de `role=` | **4** | (`grep -rn "role=" src index.html`) |
| `aria-live` | **0** | (`grep -rc "aria-live" src index.html`) |
| `:focus-visible` en styles.css | **0** | (`grep -c ":focus-visible" src/styles.css`) |
| `outline: none/0` en styles.css | **21** | (`grep -cE "outline:\s*(none|0)" src/styles.css`) |
| `tabindex` en toda la app | **4** | (`grep -rn "tabindex" src index.html`) |
| `data-accion` literales en HTML | **457** | (`grep -rEo 'data-accion="' src index.html \| wc -l`) |
| …de ellos sobre etiquetas no focusables (`div/span/td/tr/li`) | **73** | (`grep -rEo '<(div\|span\|td\|tr\|li\|em\|p\|h[1-6])[^>]*data-accion="' src index.html \| wc -l`) |
| `prefers-reduced-motion` | **0** (con 8 `@keyframes/animation:`) | (`grep -c "prefers-reduced-motion" src/styles.css` / `grep -cE "@keyframes\|animation:" src/styles.css`) |
| `html lang` | `es` correcto | index.html:2 |

Los 4 `aria-*`: boot.js:455 (`aria-hidden` en un SVG), espacio.js:364 (`aria-label="Cerrar"`), perfil-onboarding.js:126-127 (`aria-label` en chips). Los 4 `role=`: crew.js:132 y crew.js:135 (`role="button"`), perfil-onboarding.js:126-127 (`role="note"`). Es decir: **fuera de 2 componentes puntuales, cobertura ARIA cero en ~24 módulos.**

---

## 1. Sistema de modales: sin rol, sin foco, sin Escape

### 1.1 El constructor central (`src/lib/ui.js`)

Firma real:

```js
// src/lib/ui.js:25
export function showModal({ title, body, confirmLabel = 'Confirmar', cancelLabel = 'Cancelar', danger = false, onConfirm, onCancel }) {
```

El markup generado (ui.js:31-44) es `<div class="modal-backdrop"><div class="modal …">` — **sin `role="dialog"`, sin `aria-modal="true"`, sin `aria-labelledby`** (verificado: `grep -rn 'role="dialog"\|aria-modal' src index.html` → 0 resultados). El cierre:

```js
// src/lib/ui.js:67
export function closeModal() {
  document.getElementById('modalRoot').innerHTML = '';
}
```

Contrato actual del modal (implícito, y roto para teclado/SR):
- **Apertura**: `root.innerHTML = …` (ui.js:31). No hay `focus()` sobre el modal ni sobre su primer control; no se guarda `document.activeElement` — **el foco queda en el botón invocador, detrás del backdrop**.
- **Focus-trap: inexistente.** No hay ningún manejo de `Tab` (cero `keydown` en ui.js: `grep -n "keydown" src/lib/ui.js` → 0). Tab recorre toda la página bajo el backdrop.
- **Devolución de foco al cerrar: inexistente.** `closeModal()` borra innerHTML; el foco cae a `<body>`.
- **Escape: NO cierra ningún modal.** Los únicos handlers de Escape de toda la app son 2 (`grep -rn "Escape" src index.html`): buscador.js:77 (limpia el buscador global) y locaciones.js:497 (`_locLbKey`, el lightbox de fotos, que además maneja ArrowLeft/ArrowRight — locaciones.js:493-498, registrado en locaciones.js:458). El keydown global de boot.js:61-75 solo maneja `Cmd/Ctrl+,` y `Cmd/Ctrl+Z`. **El lightbox es el único overlay de la app cerrable con Escape.**
- Las únicas vías de cierre son click: acciones `ui.cerrar`, `ui.backdrop` (click en el fondo), `ui.modalCancel`, `ui.modalConfirm` (ui.js:786-790).

### 1.2 Los 30 modales "artesanales"

Hay **38 call sites de `showModal({`** (`grep -rn "showModal({" src | wc -l`) y **30 escrituras directas** `document.getElementById('modalRoot').innerHTML = …` (`grep -rn "getElementById('modalRoot').innerHTML" src | wc -l`) repartidas en bd.js (192, 432, 558, 783), config.js (144, 368, 392, 601), legal.js (380, 532, 567), gastos.js (136, `goModal()` — 1 escritura reutilizada por ~10 modales), locaciones.js (269, 504, 803), plan-rodaje.js (407, 450, 1142, 1209, 1383), cargos.js:212, invitaciones.js:42, calculadoras.js (508, 585). Ninguna añade rol, trap ni foco; heredan exactamente los mismos defectos. Varias ni siquiera tienen `data-accion="ui.backdrop"` en el fondo (p.ej. bd.js:432, legal.js:380, locaciones.js:269, plan-rodaje.js:1142, config.js:368): **esos modales solo se cierran con el botón de pie de modal** — para un usuario de teclado, jamás.

Detalle agravante: bd.js:195 usa `autofocus` en un input inyectado por `innerHTML` (único `autofocus` de la app: `grep -rn "autofocus" src index.html | wc -l` → 1) — comportamiento no garantizado en contenido dinámico; es el único intento de gestión de foco en 68 modales.

---

## 2. Navegabilidad por teclado: el hueco es estructural (está en la delegación)

### 2.1 El contrato de `delegacion.js` no contempla teclado

```js
// src/lib/delegacion.js:38-39 (dentro de despachar(ev))
  var tipos = (el.dataset.on || 'click').split(/\s+/);
  if (tipos.indexOf(ev.type) < 0) return;
```

Invariante: **un elemento `data-accion` solo responde a los tipos listados en `data-on`; el default es `click`.** El navegador solo sintetiza `click` desde Enter/Space en elementos nativamente activables (`<button>`, `<a href>`, `input`). Consecuencia: cada `div`/`span` con `data-accion` (default click) es *estructuralmente* inoperable por teclado, y no existe ningún shim que promocione keydown→acción (`grep "getAttribute('on"` → 0). En toda la app solo **4 elementos** escuchan `keydown` vía delegación (`grep -rn 'data-on="[^"]*keydown' src index.html`): boot.js:468 (Enter en login), index.html:1317 (buscador global), config.js:226 y config.js:234 (Enter agrega color/tipografía) — los cuatro son `<input>`, cero superficies de activación.

### 2.2 Sidebar y topbar

- **Sidebar: los 15 ítems de navegación de módulos son `<div class="sidebar-item" data-module="…" data-accion="app.modulo">`** (index.html:1450, 1454, 1458, 1462, 1466, 1470, 1474, 1482, 1486, 1490, 1494, 1498, 1506, 1510, 1518, 1523) — sin `tabindex`, sin `role`, sin keydown. El handler es `modulo: function (a, el) { navigateToModule(el.dataset.module); }` (boot.js:706; firma destino `export function navigateToModule(moduleKey)` nav.js:13). El CSS define `.sidebar-item:hover` (styles.css:690) pero **ningún `:focus`** (styles.css:678-714). **Cambiar de módulo dentro de un proyecto es imposible sin ratón.**
- **Topbar**: mayormente correcta (`<button>` reales: index.html:1309, 1320, 1324, 1333, 1345, 1350), **excepto** el logo/home `<div class="brand" data-accion="app.controlRoom">` (index.html:1296) — div sin tabindex: no se puede volver al Control Room por teclado. El menú de espacios que abre `app.swToggle` se puebla con `<div class="esw-item" data-accion="esp.panel">` (espacio.js:64) y `<div class="esp-acct" data-accion="esp.perfil">` (espacio.js:334): mismos defectos.
- **Control Room**: las tarjetas de proyecto son `<div class="project-card" data-project-id="…">` (kanban.js:97) activadas con `card.addEventListener('click', …)` (kanban.js:150-154), sin tabindex/role/keydown. **Abrir un proyecto tampoco es posible por teclado.** (Los chips de filtro y el view-toggle sí son `<button>`: index.html:1419-1426.)

Resultado: la ruta crítica completa (Control Room → proyecto → módulo) es 100 % ratón.

### 2.3 Acciones que solo responden a `mousedown` (inaccesibles incluso con foco)

Inventario completo (`grep -rn "mousedown" src index.html`):
- **Combobox de personas/empresas** (patrón central de la app): opciones `<div class="combobox-option" ${accionHTML('ui.cbSel', n, { on: 'mousedown' })}>` — ui.js:247, ui.js:429; réplicas en locaciones.js:673, legal.js:872, cargos.js:271 y cargos.js:275 (`cargo.invitar`, `data-on="mousedown"`). El input abre con focus/input/blur (acción `ui.respCombo`, ui.js:794-799) pero **no existe ningún manejo de flechas/Enter en el dropdown** (`grep -n "keydown\|ArrowDown" src/lib/ui.js` → 0). Un usuario de teclado puede tipear texto libre pero jamás seleccionar una opción ni disparar "+ Agregar a la BD" (ui.js:242, `data-on="mousedown click"`).
- **Buscador global**: resultados `<div class="gsearch-item" ${accionHTML('buscador.ir', i, { on: 'mousedown' })}>` (buscador.js:72). `globalSearchKey` (buscador.js:74-78) solo soporta Enter→primer resultado y Escape; sin ArrowUp/Down (la clase `.sel` está fija en el índice 0).
- **Menciones de tareas**: `<div class="mention-opt" ' + accionHTML('tm.pick', n, { on: 'mousedown' })` (tareas.js:124).
- **Chips de variables de notificaciones**: `accionHTML('ntf.var', v, { on: 'mousedown' })` (notificaciones.js:584); ídem legal `lgl.tplVar`/`lgl.tplBold` (`mousedown click`, legal.js:379, 400 — estos al menos incluyen click).
- **Redimensionado de columnas de presupuesto**: `accionHTML('pre.colGrip', …, { on: 'mousedown dblclick' })` (presupuesto-cotizacion.js:1061) y el asa de reordenar filas `data-on="mousedown"` (presupuesto-cotizacion.js:687).

### 2.4 ARIA "cosmética" que no funciona

crew.js:132 y crew.js:135 usan `<a role="button" tabindex="0" … ${accionHTML('crew.addBD', p.nombre)}>`: son focusables y anuncian "botón", pero al ser `<a>` **sin `href`** el navegador no sintetiza `click` con Enter, y la delegación solo escucha click → **teclado muerto pese al ARIA**. Son los únicos `role="button"` de la app.

---

## 3. Drag & drop: sin alternativa de teclado (y probablemente muerto — ver Hallazgo H1)

Superficies drag&drop contadas: **46 atributos inline `on*="fn("`** en HTML generado (`grep -rEo 'on[a-z]+="[a-zA-Z_]+\(' src index.html | wc -l` → 49, menos 3 que están dentro de un comentario de documentación en ui.js:150-152), repartidos en locaciones.js (10), plan-rodaje.js (21), presupuesto-cotizacion.js (15, incluye 1 `onmouseup` en 2841); más 1 zona delegada `data-on="dragover dragleave drop"` (documentos.js:39) y el asa por `mousedown` de presupuesto (presupuesto-cotizacion.js:687/875).

Funcionalidades afectadas, ninguna con alternativa de teclado ni botones subir/bajar:
- Reordenar fotos de locación (locaciones.js:260-262) y paradas de scout (locaciones.js:719-724).
- Reordenar filas del Plan de Rodaje (plan-rodaje.js:304, 338, 375) e imágenes (plan-rodaje.js:314).
- Reordenar crew/extras de la Hoja de Llamado (plan-rodaje.js:754-755, 787-788).
- Reordenar filas de presupuesto (presupuesto-cotizacion.js:758 + asa 687) y bullets/videos de cotización (presupuesto-cotizacion.js:3002-3003, 3023-3025).
- Subir archivos por arrastre a Documentos (documentos.js:39 — aquí sí existe input file alternativo).

---

## 4. Semántica

### 4.1 `button` vs `div` clickeable

- Literales en templates: **297 `<button …data-accion>`** vs **63 `<div …data-accion>` + 7 `<span …data-accion>`** (`grep -rEo "<div[^>]*data-accion" src index.html | wc -l`, ídem span/button). Vía `accionHTML` interpolado: **105 en `<button` vs 16 en `<div` + 2 en `<span`** (`grep -rEo "<button[^>]*\$\{accionHTML" src | wc -l`, etc.), más casos en `<td>/<tr>` (presupuesto-cotizacion.js:684 aprox., notificaciones.js). Total no-focusables con acción: **73** literales + ~18 interpolados ≈ **91 controles fantasma (~20 % de los 457)**. Los peores por criticidad: sidebar completo (§2.2), cabeceras de departamento del presupuesto (`<div class="dept-header" data-accion="pre.d" data-args='["toggleDept",…]'>`, presupuesto-cotizacion.js:325, 334, 343, 352), fila "agregar" (presupuesto-cotizacion.js:415), dropzones de gastos (`<div class="go-dz" data-accion="go.dz"…>`, gastos.js:699, 821) y la tarjeta "Crear presupuesto" (gastos.js:203).
- El reset global agrava: `button { font-family: inherit; cursor: pointer; border: none; background: none; }` (styles.css:135) — al menos conserva el outline nativo, pero **0 `:focus-visible`** y 21 `outline:none` en inputs (p.ej. styles.css:1008, 1369, 2471) dejan el foco visible dependiente solo de un cambio de `border-color`.

### 4.2 Imágenes, SVG, tooltips

- **7 de 17 `<img>` sin `alt`** (`grep -rEo "<img[^>]*>" src index.html | grep -vc "alt="`): plan-rodaje.js (miniaturas de hoja, 2), gastos.js (comprobantes, 3), locaciones.js (foto de ficha, 1), presupuesto-cotizacion.js (logo cliente, 1).
- **50 `<svg>` inline, solo 1 con `aria-hidden`** (boot.js:455) (`grep -rEo "<svg" src index.html | wc -l`). Los botones icon-only (campana index.html:1333, admin 1320) dependen de `title=`.
- El **tooltip global** se dispara solo con `mouseover/mouseout` (ui.js:117 y ui.js:121, `document.body.addEventListener('mouseover', …)`); **56 `data-tip`** y **144 `title=`** (`grep -rEo 'data-tip=' … | wc -l`; `grep -rEo 'title="' … | wc -l`) cuyo contenido es invisible para teclado y lector de pantalla. Excepción bien resuelta: los chips de perfil muestran su tip con `:hover/:focus/:focus-within` (perfil-onboarding.js:154).

### 4.3 Formularios

- **292 `<input>` + 47 `<select>` + 17 `<textarea>`**; **247 `<label>` pero solo 3 con `for=`** (config.js:1083, config.js:1101, config.js:2083) y ~22 que envuelven al control (`grep -rEo "<label[^>]*>[^<]*<input" … | wc -l`); **105 siguen el patrón hermano `</label><input`** (`grep -rEo "</label>\s*<(input|select|textarea)" … | wc -l`) — sin `for`/`id` no hay asociación programática: el lector de pantalla anuncia "editar texto" sin nombre. **0 inputs con `aria-label`**; 151 dependen de `placeholder` como única pista (`grep -rEo "<input[^>]*placeholder" … | wc -l`).
- **37 `<table>` generadas, 0 `scope=`/`<caption>`** (`grep -rEo "<table" src | wc -l`; `grep -rEo 'scope="|<caption' src | wc -l`) — en tablas anchas como presupuesto y hoja de llamado, la relación celda-encabezado es inaudita.
- Editores `contenteditable` sin `role="textbox"` ni nombre: legal.js:401 (`.lgl-rte`), notificaciones.js:515, 596, 606.

### 4.4 Feedback y landmarks

- `showToast({ kind = 'info', title, body, duration = 5000 })` (helpers.js) inyecta divs en `#toastContainer` (index.html:1360) **sin `aria-live`/`role="status"`**: toda confirmación/error de guardado es invisible para SR y desaparece a los 5 s.
- Landmarks: `<header>` (index.html:1294), `<nav>` breadcrumb (1305), `<aside>` sidebar (1443) correctos; pero hay **dos `<main>`** simultáneos en el DOM (`#moduleMain` index.html:1531 y `#bdGlobalMain` index.html:1545), ocultos por clase `.hidden` en la sección padre — `display:none` los saca del árbol de accesibilidad cuando aplica, pero la unicidad de `<main>` depende de ese CSS.

---

## 5. Contraste (tokens de styles.css:5-71 dark / 77-117 light)

Ratios WCAG calculados (script python3 con luminancia relativa; umbral AA texto normal 4.5, texto grande/UI 3.0):

**Tema oscuro** (default, `color-scheme: dark` styles.css:6):

| Par | Ratio | Veredicto |
|---|---|---|
| `--ink-faint` #71736a (styles.css:28) sobre `--bg-card` #262624 | **3.15** | FALLA AA texto normal |
| `--ink-faint` sobre `--bg-elevated` #2e2e2b | **2.83** | FALLA incluso 3.0 |
| `--accent` #B03A2F (styles.css:32) como TEXTO sobre `--bg-page/card` | **2.90 / 2.52** | FALLA todo |
| `--accent-deep` #d05a4d sobre card | 3.79 | solo texto grande |
| `--ink-muted` #a0a399 sobre card | 5.92 | OK |
| `--ink-onAccent` #FDFEED sobre `--accent` | 5.89 | OK |
| `--rule` #34342f sobre superficies | 1.09–1.39 | bordes casi invisibles (no-texto, límite 3.0) |

**Tema claro** (styles.css:77-117): `--ink-faint` #9a9a8f sobre #ffffff/**#f4f4ee** = **2.84/2.57 FALLA**; `--warning` #b8860b sobre page = 2.95 FALLA; `--positive`/`--state-sale` 3.0-3.6 (solo texto grande).

Magnitud del impacto: `color: var(--ink-faint)` se usa **300 veces** como color de texto (`grep -rEo "color:\s*var\(--ink-faint\)" src index.html | wc -l`) — es el color estándar de hints, metadatos y subtítulos; `--accent` como color de texto **105 veces** (`grep -rEo "color:\s*var\(--accent[,)]" src index.html | wc -l`), p.ej. el link "EDITAR ↗" (plan-rodaje.js:273) y "Marcar todas como leídas" (index.html:1340). Combinado con **175 declaraciones `font-size` ≤ 11px** en styles.css (`grep -rEo "font-size:\s*(9|10|11)(\.[0-9])?px" src/styles.css | wc -l`) — texto pequeño nunca califica como "grande" — el par *faint+11px* es una falla AA sistemática en ambos temas.

---

## 6. Top-5 de arreglos por costo/beneficio

1. **Teclado en la delegación (costo mínimo, beneficio máximo).** En `despachar` (delegacion.js:35): si `ev.type === 'keydown'` y `ev.key` es Enter/Space y el elemento no es nativamente activable, tratar como click; añadir `tabindex="0"` + `role="button"` a la salida de `accionHTML` (delegacion.js:24) cuando el tag no es focusable, o como clase CSS+atributo en los 73 literales. Un cambio en 1 archivo rehabilita ~91 controles, incluido el sidebar completo y las tarjetas de proyecto (kanban.js:150 necesita el mismo trato).
2. **Modal accesible en un solo punto (ui.js:25-69).** `role="dialog" aria-modal="true" aria-labelledby`, guardar `document.activeElement` al abrir, `focus()` al primer control, listener `keydown` en `#modalRoot` con Escape→`_modalCancel()` y trap de Tab. Como los 30 modales artesanales comparten `#modalRoot` y `closeModal()`, un listener delegado sobre el contenedor cubre a casi todos sin tocarlos.
3. **Teclado en el combobox (ui.js:225-310).** ArrowDown/ArrowUp/Enter/Escape sobre `.combobox-option` (hoy solo `mousedown`, ui.js:247/429) + `role="combobox"/"listbox"` + `aria-expanded`. Es el widget de captura de personas/empresas usado por crew, cargos, legal y locaciones: un fix, cuatro módulos. Aplicar el mismo patrón al buscador global (buscador.js:72-78).
4. **Subir `--ink-faint` y prohibir `--accent` como texto sobre oscuro (styles.css:28, 32, 89).** Cambiar dos hex (p.ej. faint ≥ #8b8d83 dark / ≤ #767669 light) corrige de golpe 300 usos; sustituir los 105 `color: var(--accent)` por `--accent-deep` (ya existe con ese propósito declarado, styles.css:33/93). Costo: editar tokens, cero componentes — exactamente el contrato que promete el comentario de styles.css:14-15.
5. **Nombres accesibles de formularios y avisos.** Generar `for`/`id` en el patrón `form-row` (105 pares hermanos ya adyacentes — mecánico), `aria-live="polite"` en `#toastContainer` (index.html:1360) y `alt` en las 7 `<img>` — beneficio alto para SR con esfuerzo trivial.

(El drag&drop necesita botones subir/bajar como alternativa, pero primero hay que resolver H1: hoy probablemente ni con ratón funciona.)

---

## Hallazgos

- **H1 (grave, funcional, no solo a11y): 46 handlers inline `on*=` sobrevivieron al desacople y están doblemente muertos.** locaciones.js:261-262, 719, 724; plan-rodaje.js:304, 314, 338, 375, 754-755, 787-788; presupuesto-cotizacion.js:758, 2841, 3002-3003, 3023-3025 emiten `ondragstart="prDragStart(event,…)"` etc. en HTML inyectado por innerHTML. (a) La CSP de index.html:35 (`script-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com`, **sin `'unsafe-inline'`**, presumida "D3: ~991 on*= eliminados" en el comentario de index.html:7-35) bloquea su ejecución; (b) aunque la CSP lo permitiera, las funciones son de ámbito de módulo sin puente (`grep -rn "window.prDragStart\|window.cotDragStart\|window.hlDragStart\|window.locScoutDragStart\|window.rowDragStart" src` → 0; sin `export`). Todo el reordenamiento por arrastre (plan de rodaje, hoja de llamado, presupuesto, cotización, fotos/scout de locaciones) y el `onmouseup="cotDescGuardarAlto(…)"` (presupuesto-cotizacion.js:2841) parecen inoperantes en producción, con violaciones CSP silenciosas en consola. Contradice el claim del commit 5e1d621 ("cero handlers inline").
- **H2: ARIA decorativa sin función.** crew.js:132/135: `<a role="button" tabindex="0">` sin `href` + delegación solo-click → Enter no hace nada; el patrón aparenta accesibilidad que no existe.
- **H3: comentario-documentación desactualizado en ui.js:140-156** — documenta el uso del combobox con `onfocus="comboboxOpen(this)"` (API inline pre-D2 que ya no existe/no funcionaría bajo CSP); induce a reintroducir el patrón prohibido.
- **H4: `ui.js:786-788` registra `cerrar`/`backdrop` "universales" pero 10+ modales artesanales no ponen `data-accion="ui.backdrop"` en su backdrop** (bd.js:432, legal.js:380, locaciones.js:269/803, plan-rodaje.js:1142, config.js:368, kanban… verificable con `grep -rn 'modal-backdrop"><' src`): inconsistencia de contrato de cierre entre modales hermanos.
- **H5: dos `<main>` en el DOM** (index.html:1531 y 1545); la unicidad del landmark depende de `.hidden` en el ancestro — frágil ante regresiones CSS.
- **H6: el buscador global marca `.sel` siempre en el índice 0** (buscador.js:72) y `globalSearchKey` solo ejecuta `_gsearchGo(0)` (buscador.js:75): la señal visual de "seleccionado" sugiere navegación por flechas que no está implementada.
- **H7: `--rule` #34342f sobre los fondos oscuros da ratios 1.09-1.39** — los separadores/bordes de inputs (única señal de foco en 21 casos con `outline:none`, p.ej. styles.css:942-944) quedan por debajo del 3:1 exigido a indicadores no textuales; el estado de foco puede ser literalmente invisible.
- **H8: `prefers-reduced-motion` ausente** con 8 animaciones/keyframes (styles.css) y un canvas de confeti (index.html:1362).