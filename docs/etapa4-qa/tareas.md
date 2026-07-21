# QA · Tareas (`frontend/src/modules/tareas.js`)

Referencia de comportamiento: monolito en `main` (`git show main:index.html`).
Módulos de apoyo: `persistencia-local.js` (markDirty), `dal.js` (project_tasks +
task_comments + task_attachments), `kanban.js`/Control Room (panel "Mis tareas"),
`lib/delegacion.js`, `lib/ganchos.js` (currentUser).
Cobertura: 12/13 ✅ (QA automatizado 2026-07-20, 0 bugs; persistencia confirmada en
project_tasks / task_comments / task_attachments + hard refresh). TM13 pendiente
(solo Invitado tiene tareas=L; requiere login con ese perfil — pasada de permisos).

> **Resultado del cruce:** la migración de Tareas es un **port fiel** del monolito
> (`_tmPush`, `tmCrear`, `tmToggle`, `tmAddComentario`, `sectionTaskCount`, `crtToggle`
> idénticos salvo `currentUser()` → gancho y markDirty). Modelo de tarea: `{id, seccion,
> texto, asignadoA, creadoPor, estado (pendiente/completada), adjuntos[], comentarios[],
> creadaTs}` en `project.data.tareas`. El juez final eres tú en `localhost:5173`.

---

Para todas: abre un proyecto → un módulo con sección (p. ej. Presupuesto o Crew) →
botón/badge "Tareas" de la sección → modal de Tareas de esa sección.

## A. Crear
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| TM1 | Crear tarea asignada | Escribe texto, elige asignado, "Crear tarea" | Aparece como pendiente; toast "Tarea creada · Asignada a X"; el contador de la sección sube | ✅ |
| TM2 | Falta el texto | "Crear tarea" con texto vacío | Toast "Falta la tarea"; no crea | ✅ |
| TM3 | Falta el asignado | Texto sin elegir asignado | Toast "¿Para quién?"; no crea | ✅ |
| TM4 | Auto-asignármela | Texto + "Auto-asignármela" | Crea la tarea asignada a mí (usuario actual), sin pedir asignado | ✅ |

## B. Editar / estado
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| TM5 | Completar y reabrir | Marca la tarea como completada; vuelve a marcar | Alterna completada↔pendiente; el contador de la sección baja/sube | ✅ |
| TM6 | Comentar | Expande la tarea, escribe un comentario, "Comentar" | Se agrega al hilo con autor y fecha | ✅ (comentario con autor + timestamp; persiste en task_comments) |
| TM7 | Adjuntar archivo | "+ Adjuntar archivo" → un PDF | Sube al bucket de adjuntos; la tarea muestra 📎 con el nombre | ✅ (sube a Storage con path; persiste en task_attachments). Nota: adjuntar re-renderiza el modal y borra el texto no guardado (igual que el monolito, no es regresión — adjunta primero, escribe después) |

## C. Menciones y contadores
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| TM8 | Mención con @ | En el texto escribe "@" | Aparece el dropdown con las personas del proyecto; al elegir, inserta "@Nombre" | ✅ (dropdown con las personas; al elegir inserta "@Arya Tarth ") |
| TM9 | Contador de sección | Crea 2 tareas, completa 1 | El badge de la sección cuenta solo las **pendientes** (no completadas) | ✅ (badge "Tareas 2" → "Tareas 1" al completar una) |

## D. Control Room — panel "Mis tareas"
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| TM10 | Mis tareas agrupadas | Con tareas asignadas a mí, vuelve al Control Room | "Mis tareas" las lista agrupadas por proyecto, con conteo | ✅ (lista la pendiente asignada a mí, agrupada por proyecto; excluye las completadas) |
| TM11 | Completar desde el panel | Marca el check de una tarea en "Mis tareas" | Se completa (crtToggle) y se refrescan métricas/kanban | ✅ (estado→completada; "Mis tareas" baja a 0) |

## E. Persistencia
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| TM12 | Round-trip tarea + comentario | Crea tarea con comentario → hard refresh | Reaparecen (project_tasks + task_comments) con texto/asignado/estado/comentario | ✅ (3 tareas + comentario + adjunto confirmados en la base y tras hard refresh) |

## F. Permiso
| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| TM13 | Solo lectura sin permiso | Perfil con `tareas`≠E intenta crear | Toast "Solo lectura · Tu perfil no puede crear tareas" | ⬜ (pendiente: solo Invitado tiene tareas=L; requiere login con ese perfil — pasada de permisos) |

**Estados:** ⬜ pendiente · 🔄 probando · ✅ pasó (no re-probar) · ❌ falló (bug abierto) · 🔁 cambió a propósito.

## Notas
- Port fiel (0 bugs esperados). Las acciones `tm.*` están registradas en delegación
  (`tm.crear`, `tm.self`, `tm.toggle`, `tm.comentar`, `tm.mention`, `tm.files`,
  `tm.crtToggle`…). Permiso de escritura: `_puedeEditarTareas` = `authNivel('tareas')==='E'`.
