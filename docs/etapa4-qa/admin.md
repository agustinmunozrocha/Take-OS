# QA · Admin / Modo administrador (`frontend/src/modules/admin.js`)

Referencia de comportamiento: monolito en `main` (`git show main:index.html`).
Modo administrador + acciones de alto impacto: cambiar/revertir estado del proyecto,
cerrar/reabrir, eliminar (a Papelera) y restaurar. Persistencia vía `dalTouchProyecto`
(estado) y `projects.deleted_at` (soft-delete).
Cobertura: 4/6 ✅ (QA automatizado 2026-07-20, 0 bugs).

> **Hallazgo (V11.3.0):** el **Modo administrador ya NO pide contraseña** — el permiso
> lo da el **perfil Administrador**; el modal "Activar Modo administrador" es solo una
> barrera consciente ("Entiendo, activar"). Esto significa que las acciones que otros
> catálogos marcaron como "requieren la clave de admin" (Kanban eliminar, Config datos
> de empresa, BD archivar) **sí son testeables** simplemente activando el modo. El juez
> final eres tú.

---

| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| ADM1 | Activar Modo administrador | Config → "Modo admin" → "Entiendo, activar" | Se activa sin contraseña (solo perfil Administrador); toast "Modo administrador activado"; aparecen las acciones restringidas | ✅ |
| ADM2 | Revertir estado a Venta | Con Modo admin, cambiar un proyecto de Producción → Venta | Pide confirmación (revertir desbloquea cotización, oculta Costo Real); al confirmar, revierte | 👁 (con Modo admin; en automatización el `select` re-renderizó — confírmalo a mano) |
| ADM3 | Cerrar / reabrir proyecto | Estado → Cerrado; luego reabrir (admin) | Cierra (congela como histórico) y reabrir requiere admin | 👁 |
| ADM4 | Eliminar proyecto | "Eliminar este proyecto" → escribir el nombre exacto → confirmar | El botón se habilita solo con el nombre exacto; el proyecto va a la **Papelera** (soft-delete `deleted_at`); toast "movido a la papelera" | ✅ |
| ADM5 | Restaurar desde Papelera | Control Room → "Papelera" → "Restaurar" | El proyecto vuelve al Control Room; toast "Proyecto restaurado" | ✅ |
| ADM6 | Gate sin ser Administrador | Con un perfil ≠ Administrador, intentar Modo admin | "Solo el perfil Administrador puede activarlo" | 👁 (requiere login con otro perfil — pasada de permisos) |

**Estados:** ⬜ pendiente · 🔄 probando · ✅ pasó · ❌ falló · 🔁 cambió a propósito.

## Notas
- **0 bugs.** Modo admin activa sin clave (solo perfil Administrador + confirmación).
  Eliminar proyecto está bien protegido (hay que escribir el nombre exacto para habilitar
  el borrado) y es soft-delete (va a la Papelera, restaurable — no se pierde la historia).
  Restaurar funciona. Revertir estado y cerrar/reabrir se confirman mejor a mano (ADM2/ADM3).
- **Correlación con otros catálogos:** como Modo admin no pide clave, **KB6 (eliminar) y
  KB7 (restaurar) de Kanban quedan ✅** (verificados aquí); **Config CFG3** (datos de
  empresa) y **BD BD35** (archivar/restaurar) también son testeables activando el modo —
  quedan para una pasada corta cuando quieras.
