# Cambios post-modularización

> **Registro vivo.** Lista los cambios aplicados al **monolito de producción**
> (`index.html` en `~/Software`, rama `main`) **después** de que arrancó la
> modularización con Vite (que vive en el repo de staging, `~/Software-staging`,
> y en las ramas congeladas `vite-andamiaje` / `etapa1-lib`).
>
> Estos cambios **NO están en el repo modular**. Cuando la modularización se
> complete y se haga el corte de producción a la build de Vite, **cada fila de
> abajo debe portarse** a la base modular para no perder el trabajo. Este doc es
> el checklist para Juan (CTO).
>
> **Se acumula:** cada vez que se hace un cambio al monolito de `main`, se agrega
> una fila aquí en el mismo momento del merge.

## Pendientes de portar al repo modular

| # | Fecha | Commits en `main` | Versión | Qué es | Dónde vive en el monolito | Portado |
|:-:|-------|-------------------|---------|--------|----------------------------|:-------:|
| 1 | 30-jun-2026 | `082c501` (fix) · `fa008d5` (merge) | V11.31.0 | **Finanzas (CFO):** validar gastos y las acciones de la cola ahora SÍ persisten (encolan `dalTouchProyecto` tras marcar el cambio). Sin cambios de BD. | `goValidar`, `goPagarReemb`, `goPagarTodos`, `goSetFechaPago`, `goSetObjetivo` | ☐ |
| 2 | 07-jul-2026 | `73ea781` (fix) · `bf76ca6` (merge) | V11.32.0 | **Login:** el error de OAuth deja de ser un rebote mudo; se muestra un mensaje y se limpia el `#error` de la URL. (El copy de este commit se **ajustó en el #3** — portar el net #2+#3.) Sin cambios de BD. | `AUTH_ERROR_OAUTH` (junto a `AUTH_RETORNO_OAUTH`), `cloudGate`, hint `#cgInvHint`, modal "Invitación creada" (`_invMostrarResultado`) | ☐ |
| 3 | 07-jul-2026 | `c2ef3f3` (fix) · `7d6c6c0` (merge) | V11.33.0 | **Login (ajuste del #2):** TakeOS es de **registro abierto** (cualquiera puede crearse cuenta). Se conserva la detección de error de login pero con mensaje **neutro** (*"No se pudo iniciar sesión…"*) y se **revierte** el copy invitado-céntrico del #2 (se restaura *"tu cuenta se crea sola"* y el modal). **El net del login a portar = #2 + #3.** Sin cambios de BD. | `AUTH_ERROR_OAUTH`/`cloudGate` (mensaje), hint `#cgInvHint`, modal `_invMostrarResultado` | ☐ |
| 4 | 07-jul-2026 | `0ae6727` (fix) · `c8fee51` (merge) | V11.34.0 | **Rebrand TakeOS → Rizora (marca visible):** 80 ocurrencias CamelCase → "Rizora" (textos, títulos, `<title>`, valor de `TAKEOS_MARCA`, y 3 funciones renombradas parejo) + versión in-app a **V11.34.0**. **NO** se tocaron identificadores/claves internas (`takeos_*` del navegador, protocolo `TAKEOS_REQUISITOS`, URL del landing). Docs `.md` pendientes de rebrand. Sin BD. | Global en `index.html`; `TAKEOS_VERSION` (línea 24092), `TAKEOS_MARCA` (24303) | ☐ |

## Cómo usar este registro

- **Al hacer un cambio nuevo al monolito de `main`:** agregar una fila con número
  correlativo, fecha, los commits (fix + merge), la versión del CHANGELOG, un
  resumen en simple y las funciones/zonas tocadas.
- **Al portar un cambio al repo modular:** marcar la casilla "Portado" (☑) cuando
  el equivalente exista y esté probado en la base modular.
- **Contexto de la deuda:** hoy el monolito se mantiene en dos lugares (prod
  `~/Software/index.html` y staging `frontend/index.html`); cada fila de esta
  lista se aplicó en prod y falta replicarla en el modular. Ver el handoff de
  reconciliación de la modularización para el estado del refactor.
