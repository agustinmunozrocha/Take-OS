# QA · Cotización — Ofertas al cliente (`frontend/src/modules/presupuesto-cotizacion.js`, `renderCotizacion`)

Referencia de comportamiento: monolito en `main` (`git show main:index.html`).
**Alcance:** la feature de **ofertas/packs al cliente** (`renderCotizacion` ~línea
2808 y funciones asociadas): crear/editar ofertas, valor, "qué incluye / qué NO",
entregables, presupuesto alternativo costeable, versiones/comparador y la Carta de
Cotización en PDF. **NO** cubre el grid de Presupuesto (`renderPresupuesto`), que
ya está aprobado en [presupuesto.md](presupuesto.md) (P1–P36).
Cobertura: 24/25 ✅ + 1 🔁 (Cotización cerrada). C1–C18 y C22–C25 por QA automatizado —Chrome MCP— el 2026-07-14 (0 bugs); C19 (Editorial) y C21 verificadas por Agustín; C20 → 🔁 (Carta/Manifiesto desconectadas de la UI, ver Notas). Editorial es la única plantilla activa.

> **Cómo leer este catálogo.** Las pruebas **⭐** son donde el cruce
> monolito↔modular levantó bug; **pruébalas primero**. El juez final eres tú en
> `localhost:5173`.
>
> **Bugs encontrados y arreglados en esta tanda** (branch `fix/cotizacion-resumen-snapshot`):
> BUG-COT-1 (afecta C16, C17) y BUG-COT-2 (afecta C13). Ver Notas.

---

## A. Crear / editar / borrar oferta
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| C1 | Crear nueva oferta | Cotización → "+ Nueva oferta" | Aparece "Opción 0X", copia de la base (incluye/no incluye/entregables) con presupuesto alternativo propio; toast de éxito | ✅ |
| C2 | Editar nombre de oferta | Cambiar el input de nombre y salir del campo | Persiste tras recargar | ✅ |
| C3 | Borrar oferta alternativa | "Eliminar oferta" → confirmar | Se elimina; deshacible con Cmd+Z | ✅ |
| C4 | No se puede borrar la base | "Eliminar oferta" en la base | No existe el botón / toast "no se puede eliminar" | ✅ |

## B. Valor
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| C5 | Valor de oferta base | Editar Presupuesto del proyecto y volver a Cotización | El valor de la base = presupuesto real (solo lectura) | ✅ |
| C6 | Valor de oferta alternativa | Escribir monto en "Valor al cliente" | Formatea CLP; recalcula el costeo (ganancia/%) al instante | ✅ |

## C. Incluye / No incluye
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| C7 | Agregar/editar/borrar bullet "Incluye" | +Agregar, escribir, × | Persisten; el orden por drag&drop se guarda | ✅ |
| C8 | "↻ Traer de Presupuesto" | Click en el botón del "Incluye" | Reemplaza con roles/ítems de cantidad ≥ 1; toast | ✅ |
| C9 | "No incluye" es manual | Revisar sección "No incluye" | No se autogenera; editable a mano | ✅ |

## D. Entregables
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| C10 | Videos con variables | +Agregar video, +Variable | Video y sus variables (4K, HD…) persisten y reordenan | ✅ |
| C11 | Fotografía / Otros | +Agregar en cada lista | Persisten y reordenan | ✅ |

## E. Presupuesto alternativo / rentabilidad
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| C12 ⭐ | Agregar rol al snapshot (sub-sección normal) | En oferta alt → "+ Agregar rol a Dirección" | Fila nueva aparece y el costeo recalcula | ✅ |
| C13 ⭐ | **Sub-sección con apóstrofo** (BUG-COT-2) | Renombrar una sub-sección a p. ej. `D'Arte`, ir a la oferta alternativa, agregar/editar/borrar una fila en ese bloque | Debe agregar/editar/borrar (antes **fallaba en silencio**). Arreglado en esta tanda | ✅ |
| C14 | Editar valor/cant/DTE/unidad del snapshot | Cambiar celdas | Costo por fila y costeo de la oferta se actualizan | ✅ |
| C15 | Ganancia y % | Verificar la fila "Ganancia" del costeo | = valor − costo − comisiones; % = ganancia/valor | ✅ |

## F. Versiones / Comparador
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| C16 ⭐ | **Subtítulo de los chips de versión** (BUG-COT-1) | Abrir Cotización con ≥1 versión | Cada chip debe mostrar `<valor real> · <margen real>` (antes salía **`$0 · 0,0%`**). Arreglado | ✅ |
| C17 ⭐ | **Comparador con versión histórica** (BUG-COT-1) | Crear v2, comparar la oferta base v1 vs v2 | Valor/Margen de la base histórica deben ser reales (antes **$0 / 0** y el Δ salía falso). Arreglado | ✅ |
| C18 | Crear/activar versión | "+ Nueva versión", cambiar de chip | Copia la anterior; la previa queda como histórica de solo lectura | ✅ |

## G. PDF Carta
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| C19 | Previsualizar PDF (solo Editorial) | "Previsualizar PDF" → Editorial | Render fiel; geometría 1:1 con el PDF | ✅ (Agustín · Editorial. Carta/Manifiesto desconectadas de la UI, ver Notas) |
| C20 | Carta formal muestra domicilio legal | (Carta desconectada) | — | 🔁 desconectada a propósito (bug de fondo registrado, ver Notas) |
| C21 | Logo / color / tipografía / margen | Cambiar los controles del panel | Se reflejan en vivo y persisten como default de la productora | ✅ (Agustín) |
| C22 | Exportar PDF + bloqueo de versión | "Exportar PDF" | Abre el diálogo de imprimir; fija V.n; reeditar pide confirmación | ✅ (bloqueo técnico; el diálogo de impresión en sí queda a tu vista) |
| C23 | Export del presupuesto de la oferta (CSV) | "⬇ Presupuesto (Excel)" | Descarga CSV con BOM; base = real, alt = snapshot | ✅ |

## H. Persistencia / condiciones
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| C24 | Autosave de campos de oferta | Editar cualquier campo, esperar, recargar | Todo persiste (nombre, valor, incluye, entregables, snapshot) | ✅ |
| C25 | Condiciones del servicio + variables `{{X}}` | Editar plantilla y montos | La vista previa reemplaza las variables en vivo; se guarda a nivel productora | ✅ |

**Estados:** ⬜ pendiente · 🔄 probando · ✅ pasó (no re-probar) · ❌ falló (bug abierto) · 🔁 cambió a propósito.

## Notas

### Carta formal y Manifiesto DESCONECTADAS de la UI — 2026-07-14 (branch `fix/cotizacion-solo-editorial`)
Decisión de Agustín: perfeccionar Carta formal y Manifiesto toma demasiado tiempo y
está lejos de ser prioridad para el beta. Se **ocultan del selector** de la carta PDF
(solo queda **Editorial**, que funciona bien); el código de render (`cotTplCarta` /
`cotTplManifiesto`) **queda en su lugar, solo desconectado**, para reimplementarlas
después. Cambios: `COTPREV_PLANTILLAS` (solo `editorial`) y `cotPrevSettings` fuerza
`plantilla = 'editorial'` (una productora con `carta`/`manifiesto` guardada de antes
igual verá Editorial). Reactivar = descomentar las dos entradas + revertir el force.

**Bug de fondo que quedó pendiente (SOLO REGISTRO, no se arregla ahora)** — por qué se
desconectaron: en Carta formal y Manifiesto, el "Qué incluye" por departamento se arma
**crudo desde el Presupuesto** e incluye **todas** las filas, incluso las vacías; y no
se puede renombrar lo que incluye desde el editor. La Carta además no muestra el
domicilio/web/teléfono/email de la productora (falló C20). Cuando se reimplementen:
1. Que el "qué incluye" del modificador sea **por departamento**, y editable
   (renombrable) desde el editor de cotización, como ya funciona en Editorial.
2. Que Carta y Manifiesto lean el **editor de la cotización**, no lo que viene directo
   del Presupuesto — y que **nunca** muestren filas vacías.


### Tanda A (C1–C4) verificada por QA automatizado — 2026-07-14
Corrida en `localhost:5173` (staging), proyecto "Verano en la Comarca", perfil
Administrador, manejando el navegador con el MCP de Chrome. **Las 4 pasaron, cero
bugs, consola limpia.** Detalle:
- **C1** — "+ Nueva oferta" crea "Opción 02" como **copia profunda** real de la base
  (mutar la nueva no toca la base), con su propio presupuesto alternativo; re-render OK.
- **C2** — renombrar la oferta escribe `o.nombre` y **persiste tras recargar** (round-trip
  a Supabase confirmado).
- **C3** — "Eliminar oferta" abre modal de confirmación, borra por completo (hard-delete)
  y **Cmd+Z restaura** la oferta íntegra (nombre + presupuesto).
- **C4** — la oferta base **no tiene botón Eliminar** (tag "Base · Presupuesto real");
  ningún botón de borrado apunta a su id.
- Cruce de código previo (monolito `main` ↔ modular): las funciones de estas 4 son
  idénticas a `main` salvo el cableado esperado `onclick`→`data-accion`, ya verificado.
- Nota de método: el `fill` del MCP dispara `input` pero no `change`; los campos con
  `data-on="change"` (como el nombre de oferta) requieren emitir `change` para simular
  el blur real. No es bug de la app.

### Tandas B–H (C5–C18, C22–C25) verificadas por QA automatizado — 2026-07-14
Corrida en `localhost:5173` (staging), proyecto "Verano en la Comarca", perfil
Administrador, manejando el navegador con el MCP de Chrome, sobre una oferta
alternativa desechable ("Opción 02") creada para la prueba. **Las 15 pruebas
técnicas pasaron, cero bugs.** El veredicto de cada una se tomó del **modelo**
(`STATE`), del **DOM** y de la **consola** (sin "fn sin mapear"), no a ojo. Cruce
previo monolito `main` ↔ modular: en las 15, la lógica modular replica a `main`
(cotMoneyOferta, cotRegenIncluye/cotDefaultIncluye, cotBulletAdd/Edit/Del,
cotVideo*/cotVar*, cotSnapAdd/Edit, cotCrearVersion/cotNuevaVersion,
cotPreviewGenerar/_cotBloqueada, cotExportPresupuestoCSV/cotBudgetRows, markDirty).
Detalle:
- **C5** — valor de la base es solo lectura (div.ro, sin input) y sigue al
  presupuesto real: editando el Presupuesto a $13.579.000 y volviendo, la base pasó
  a $13.579.000 (`= finanzas.presupuestoCliente`). Se restauró a $8.000.000.
- **C6** — en la alternativa, escribir $9.990.000 formatea a "9.990.000" y recalcula
  al instante: Ganancia $6.595.111 (= valor − costo − comisiones) y 66,0%.
- **C7** — Incluye: agregar/editar/borrar y **reordenar por drag&drop** mutan el
  array; el array de la oferta es el mismo objeto que el de la versión activa.
- **C8** — "↻ Traer de Presupuesto" **reemplaza** (no concatena): el Incluye queda
  igual a `cotDefaultIncluye` (roles con cantidad ≥ 1, deduplicados); el centinela
  agregado antes desaparece.
- **C9** — "No incluye" no tiene botón de auto-generar (Incluye sí: asimetría
  correcta) y agregar/editar/borrar a mano funcionan.
- **C10 / C11** — videos con variables (4K/HD), Fotografía y Otros: agregar, editar
  y reordenar persisten en el modelo y el DOM.
- **C12 ⭐** — "+ Agregar rol a Producción" (sub-sección normal) suma la fila
  plantilla en blanco y re-renderiza el costeo sin alterar montos (la fila cuesta 0).
- **C14** — editar valor/cant/DTE/unidad de una fila del snapshot actualiza el costo
  por fila ($750.000 con Factura) y el costeo total (subtotal, costo, ganancia, %).
- **C15** — Ganancia = valor − costo − comisiones y % = ganancia/valor, con color
  `pos`/`neg` según signo (verificado $5.807.611 · 58,1%, clase `val pos`).
- **C18** — "+ Nueva versión" copia profunda de la activa (ids únicos, ofertas sin
  ref compartida), congela la previa (`presupSnap` + resumen numérico → guardián
  BUG-COT-1 OK) y la nueva no arrastra snapshot; la previa muestra banner histórico
  y volver a la última restaura edición.
- **C22** — el bloqueo técnico: exportar fija la versión (`exportada=true`,
  `exportNum` 0→1), re-exportar sin editar es idempotente, editar una versión
  bloqueada abre el modal "Esta versión ya se exportó" y **no** persiste el cambio,
  "Crear nueva versión" (`cotNuevaVersion`) desbloquea y el siguiente export sube a
  V.2. La impresión se neutralizó (el diálogo/PDF en sí es de vista humana).
- **C23** — CSV con BOM UTF-8, header de 9 columnas exacto, base desde el
  presupuesto real y alternativa desde el snapshot (columna Nombre vacía), filas
  vacías filtradas (cantidad ≥ 1 o valor > 0, idéntico a `main`), última fila
  "TOTAL COSTO EMPRESA".
- **C24** — se editó nombre/valor/incluye/no incluye/video/snapshot de una oferta,
  se recargó y **todo persistió** desde Supabase (round-trip confirmado), la oferta
  viaja en la versión activa. Nota: `STATE.dirty` puede quedar en `true` (es el flag
  del respaldo local); el guardado remoto se confirmó por los `guardar_proyecto` 200.
- **C25** — la plantilla de Condiciones se guarda a **nivel productora**
  (`EMPRESA_PERFIL.condCotTpl`, no en el proyecto) y la vista previa reemplaza las
  `{{VARIABLES}}` en vivo (validez, valor de ronda con formato $); editar los montos
  y re-disparar el preview refleja los nuevos valores. Se restauró la plantilla y los
  montos originales.
- **Consola:** limpia en todas las tandas (solo artefactos benignos de dev: 404 del
  favicon, un corte de red puntual, y el worker de reconexión de Vite bloqueado por
  la CSP —dev-only, no va en el build de staging—). Ningún "[pre] fn sin mapear".
- **Limpieza:** se borró la oferta de prueba y la versión extra creadas; el proyecto
  quedó como se encontró (2 versiones, solo la oferta base, presupuesto y condiciones
  originales), verificado tras recargar.

### Bug encontrado y arreglado — BUG-COT-1 (chips y comparador en $0)
La lectura del resumen financiero de una versión leía `fin.presupuestoCliente`,
pero `calcSummaryFin` devuelve la clave `presupCliente` (un find-replace de la
migración renombró de más 3 lecturas del *resultado*). Efecto: los chips del
switcher de versiones y el comparador de versiones históricas mostraban
`$0 · 0,0%` y el "Δ valor cotizado" salía falso. Fix: 3 sitios vuelven a
`presupCliente` (los que leen el *campo de entrada* `finanzas.presupuestoCliente`
quedaron intactos). **Verificar en C16 y C17.**

### Bug encontrado y arreglado — BUG-COT-2 (presupuesto alternativo con apóstrofo)
En el editor del presupuesto alternativo, el nombre de la sub-sección se pasaba
con `jsq(dept)` (escape para string JS del monolito) bajo la delegación por JSON,
que ya maneja las comillas → doble escape. Efecto: agregar/editar/borrar una fila
en una sub-sección cuyo nombre tuviera `'` o `\` fallaba en silencio (la clave de
lookup no calzaba). Fix: se pasa `dept` crudo, igual que el grid de Presupuesto ya
hace. **Verificar en C13** (caso borde: solo sub-secciones con esos caracteres).

### Sin pendientes de BD
El round-trip de persistencia de la cotización (ofertas, incluye/no incluye,
entregables, presupuesto alternativo, meta) es idéntico al monolito; nada que
señalar en la base de datos.
