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
| 2 | 07-jul-2026 | `73ea781` (fix) · `bf76ca6` (merge) | V11.32.0 | **Login:** el error de OAuth (signup deshabilitado / rechazo de Google) deja de ser un rebote mudo; se muestra un mensaje claro al invitado, se limpia el `#error` de la URL y se corrige el copy que prometía "tu cuenta se crea sola". Sin cambios de BD. | `AUTH_ERROR_OAUTH` (junto a `AUTH_RETORNO_OAUTH`), `cloudGate`, hint `#cgInvHint`, modal "Invitación creada" (`_invMostrarResultado`) | ☐ |

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
