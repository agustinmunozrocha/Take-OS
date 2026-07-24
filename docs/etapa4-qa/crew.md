# QA · Crew (`frontend/src/modules/crew.js`)

Referencia de comportamiento: monolito en `main` (`git show main:index.html`).
Módulos de apoyo: `plan-rodaje.js` (getConfirmedCrew, printViaIframe), `dal.js`
(persistencia crew externos / medio de transporte), `bd.js` (auto-lookup), `lib/delegacion.js`.
Cobertura: 8/18 ✅ (QA automatizado 2026-07-20, 0 bugs) · 3 👁 PDF (Agustín) ·
CR1/CR2/CR3/CR6/CR7 pendientes (espejo del Presupuesto, requieren preproducción) ·
CR4/CR18 incompletos (requieren proyecto vacío).

> **Resultado del cruce:** la migración de Crew es un **port fiel** del monolito.
> No se encontraron regresiones (0 bugs). Las pruebas **⭐** son los caminos que
> pasaron por delegación/ganchos/RPC en la migración: se verificaron leyendo
> código, conviene una pasada manual de confirmación. El juez final eres tú en
> `localhost:5173`.

---

## A. Espejo del Presupuesto
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| CR1 | Solo confirmados con nombre | En Presupuesto marca "Conf." a una persona con nombre; abre Crew | Aparece en la tabla; KPI "Personas confirmadas" +1 | ⬜ (pendiente: espejo del Presupuesto; el proyecto QA está en modo "solo cotización" y los controles de rodaje no se exponen — probar con proyecto en preproducción) |
| CR2 | Filtro "no va a rodaje" excluye | Marca una fila confirmada como "no va a rodaje"; abre Crew | NO aparece en Crew | ⬜ (pendiente: requiere el toggle "no rodaje" del Presupuesto, no expuesto en cotización) |
| CR3 | Deduplicación por nombre | Misma persona confirmada en 2 roles/secciones | Aparece 1 sola vez (primer rol encontrado) | ⬜ (pendiente: espejo del Presupuesto) |
| CR4 | Estado vacío | Proyecto sin confirmados | Alert "Aún no hay crew confirmado…"; Externos + exports igual disponibles | ⬜ (incompleto: requiere un proyecto sin confirmados) |

## B. Auto-lookup desde la BD
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| CR5 ⭐ | Persona en BD muestra datos | Crea persona en BD; confírmala en Presupuesto; abre Crew | Muestra teléfono/mail/restricción/dirección/comuna; KPI "En base de datos" +1 | ✅ (QA auto 2026-07-20: los 4 confirmados muestran tel/mail/dirección/comuna; KPI "En base de datos" = 4) |
| CR6 ⭐ | Persona sin BD | Confirma un nombre que no está en la BD | Muestra "⚠ Sin BD"; KPI "Faltan en BD" +1 | ⬜ (pendiente: requiere confirmar en Presupuesto una persona fuera de la BD — espejo del Presupuesto) |
| CR7 ⭐ | Link "Agregar a la BD" | Click en "⚠ Sin BD" / "+ Agregar persona a la BD" | Abre el alta de Persona con el nombre precargado | ⬜ (pendiente: depende de CR6) |

## C. Crew externos
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| CR8 ⭐ | Medio de transporte persiste | Elige un medio en el select; navega a otro módulo y vuelve; recarga | El valor elegido se mantiene | ✅ (QA auto 2026-07-20: "Uber / Cabify" en Arya persiste — confirmado en la base project_crew_extra + hard refresh) |
| CR9 ⭐ | Agregar externo | Click "+ Agregar externo" | Nueva fila, tipo "cliente" por defecto, campos vacíos | ✅ (QA auto 2026-07-20) |
| CR10 ⭐ | Editar campos del externo | Cambia tipo/nombre/rol/teléfono/restricción/dirección/comuna | Cada cambio se guarda al salir del campo | ✅ (QA auto 2026-07-20: los 7 campos se guardan al change; persisten en project_external_crew) |
| CR11 ⭐ | Quitar externo | Click en "×" | La fila se elimina y se re-dibuja | ✅ (QA auto 2026-07-20) |
| CR12 ⭐ | Persistencia de externos | Agrega 2 externos con datos; recarga la página | Ambos reaparecen con todos sus campos, en orden | ✅ (QA auto 2026-07-20: 2 externos confirmados en la base + hard refresh, en orden) |

## D. Exportar PDF
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| CR13 ⭐ | Crew List (PDF) | Con crew + externos, "Crew List (PDF)" | PDF "CREW LIST", columnas Rol/Nombre/Teléfono/Mail/Restricción; externos con tag de tipo; subtítulo proyecto·cliente·N | 👁 (PDF — la mira Agustín) |
| CR14 ⭐ | Catering (PDF) | Click "Catering (PDF)" | PDF "CATERING", columnas Rol/Nombre/Restricción; restricción ≠ "Ninguna" resaltada en rojo | 👁 (PDF — la mira Agustín) |
| CR15 ⭐ | Transporte — selección | Click "Transporte (PDF)" | Modal con todas las personas pre-marcadas; muestra dirección/comuna | ✅ (QA auto 2026-07-20: modal con todas pre-marcadas + dirección/comuna) |
| CR16 ⭐ | Transporte — modal | Desmarca a alguien; click dentro del modal | El check se respeta; click dentro NO cierra; solo cierra en el fondo o Cancelar | ✅ (QA auto 2026-07-20: desmarcado respetado; clic interno no cierra; backdrop sí cierra) |
| CR17 ⭐ | Transporte — PDF final | "Exportar seleccionados" | PDF "TRANSPORTE": Nombre/Rol/Teléfono/Dirección(link Maps)/Comuna, solo los marcados; si nadie, toast de aviso | 👁 (PDF — la mira Agustín) |
| CR18 | Export sin personas | Sin crew ni externos, click cualquier export | Toast "Sin personas"; no genera PDF | ⬜ (incompleto: requiere un proyecto sin crew ni externos) |

**Estados:** ⬜ pendiente · 🔄 probando · ✅ pasó (no re-probar) · ❌ falló (bug abierto) · 🔁 cambió a propósito.

## Notas
- **0 bugs.** Migración fiel: las 12 acciones (`crew.pdfCrew`, `crew.addBD`,
  `crew.ext`, `crew.selTrans`, `crew.transExport`, etc.) tienen handler
  registrado; cero `on*=` inline; el round-trip de crew externos y medio de
  transporte es idéntico al monolito; los ganchos (`renderCrew`,
  `getCrewForExport`) están definidos y consumidos.
- **No-regresiones verificadas** (main hace igual): el select de transporte no
  llama `markDirty` propio, pero el listener global de `change` sí lo marca
  (paridad); el modal de transporte no cierra al click interno (equivalente al
  `stopPropagation` del monolito). `crewExternos` no persiste `mail` — igual en
  ambas versiones (no es de esta migración).
