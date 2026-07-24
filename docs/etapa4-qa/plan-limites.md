# QA · Plan / Límites (`frontend/src/modules/plan-limites.js`)

Referencia de comportamiento: monolito en `main` (`git show main:index.html`).
Módulo pequeño y **sin estado/persistencia**: es el manejador central de los códigos
de límite de plan que devuelve la base (`TAKEOS_PLAN_LIMITE:<recurso>:<máx>` /
`TAKEOS_PLAN:<módulo>`) + los carteles de venta sobrios + la CTA de la landing.
Cobertura: 4/6 verificadas por código (port fiel) · 2 👁 (QA 2026-07-20, 0 bugs).

> **Resultado del cruce:** `manejarErrorPlan` es **idéntico** al monolito (mismo regex,
> mismos textos; el tope se lee SIEMPRE del propio error). No hay lógica nueva. Como es
> un formateador puro disparado por **errores del backend**, ejercerlo en vivo exige
> chocar un tope real (lo mismo que CG16 en Cargos). El juez final eres tú.

---

| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| PL1 | Tope de proyectos | La base devuelve `TAKEOS_PLAN_LIMITE:proyectos:N` | Modal sobrio "Tope de proyectos de tu plan" con el número **N** leído del error; CTA "Ver planes" | ✅ (verificado por código — port fiel; en vivo requiere chocar el cupo de proyectos) |
| PL2 | Tope de colaboradores | La base devuelve `TAKEOS_PLAN_LIMITE:colaboradores:N` | Modal "Tope de colaboradores de tu plan" con **N**; CTA "Ver planes" | ✅ (verificado por código; en vivo = CG16, requiere sembrar 12 colaboradores) |
| PL3 | Módulo no incluido (Finanzas) | La base devuelve `TAKEOS_PLAN:finanzas` | Pantalla de "módulo bloqueado" 🔒 (no modal) con "Ver planes" | ✅ (verificado por código; en vivo requiere un plan sin Finanzas) |
| PL4 | Error no-plan pasa de largo | Un error cualquiera (no `TAKEOS_PLAN…`) | `manejarErrorPlan` devuelve `false` → el caller sigue con su manejo normal | ✅ (verificado por código) |
| PL5 | CTA "Ver planes" | Click en "Ver planes" del modal/pantalla | Abre la landing (`takeos-landing`) en pestaña nueva | 👁 (abre pestaña nueva — mírala) |
| PL6 | CTA "¿Tienes una productora?" | Usuario persona natural SIN productora | Cartel discreto, descartable por sesión; "Saber más" → landing | 👁 (requiere un usuario sin organización) |

**Estados:** ⬜ pendiente · 🔄 probando · ✅ pasó · ❌ falló · 🔁 cambió a propósito.

## Notas
- **0 bugs.** `manejarErrorPlan`, `_planModalVenta`, `_planModuloBloqueado` y las CTAs
  son port fiel del monolito. El tono de venta es "hecho + salida + CTA" (cerrado por
  Agustín). El número del tope se lee del error, así que cambiar los límites en la base
  no obliga a tocar este módulo. Los disparos en vivo dependen de errores del backend
  (topes reales), no reproducibles en el QA rápido sin sembrar los límites.
