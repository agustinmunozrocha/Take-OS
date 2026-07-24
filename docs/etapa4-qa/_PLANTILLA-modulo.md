# QA · <Módulo> (`frontend/src/modules/<archivo>.js`)

Referencia de comportamiento: monolito en `main` (`git show main:index.html`).
Cobertura: X/Y pruebas ✅.

| ID | Corre | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-------|-----------|-------|-------------------------|--------|
| P1 | 🤖 | <cálculo / acción> | <pantalla → acción → acción> | <resultado correcto> | ⬜ |
| P2 | 🤖 | Persistencia | Cambiar X, recargar | X sigue guardado | ⬜ |
| P3 | 🤖 | Columnas | Mover / renombrar columna | Se refleja y persiste | ⬜ |
| P4 | 👁 | <render / PDF / estética> | <...> | <se ve correcto> | ⬜ |

**Estados:** ⬜ pendiente · 🔄 probando · ✅ pasó (no re-probar) · ❌ falló (bug abierto) · 🔁 cambió a propósito.
**Corre:** 🤖 la corre Claude solo (modelo/DOM/consola) · 👁 necesita la vista de Agustín (render/PDF/estética/UX).

## Notas
- ❌ / 🔁: anotar aquí el detalle (qué bug, o por qué cambió a propósito).
