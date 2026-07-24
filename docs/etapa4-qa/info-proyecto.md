# QA · Info Proyecto (`frontend/src/modules/info-proyecto.js`)

Referencia de comportamiento: monolito en `main` (`git show main:index.html`).
Módulos de apoyo: `admin.js` (cambio de estado + gate + confeti), `cargos.js`
(fuente de los responsables RECI), `bd-excel.js` / `lib/state.js` (BD personas y
empresas), `kanban.js` (Papelera/restaurar), `persistencia-local.js` + `dal.js`
(guardado). Cobertura: 19/19 ✅ (con mejoras pendientes en el Grupo 2 — ver nota de cierre).

> **Cómo leer este catálogo.** Las pruebas marcadas **⭐** en "Qué probar" son
> donde el cruce monolito↔modular levantó sospecha de que la migración pudo
> romper algo: **pruébalas primero**. El resto son cobertura de regresión normal.
> El juez final eres tú en `localhost:5173`; esto es la guía para no olvidar nada.

---

## A. Identidad del proyecto

| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| I1 | ⭐ Combobox **Cliente** contra BD de empresas | Escribe en "Cliente" | Se abre el desplegable filtrando empresas de la BD. Si el texto no coincide con ninguna, aparece "⚠ No está en la BD de empresas — puedes seguir igual" con "+ Agregarla a la BD". *(Sospecha: el combobox migró de handlers inline a delegación de 4 eventos —foco/tipeo/salir/elegir—; si uno no dispara, el filtro o el aviso fallan.)* | ✅ |
| I2 | ⭐ Cambiar **Cliente** sincroniza el header | Cambia el texto de "Cliente" | El nombre del cliente se actualiza **en vivo** en la barra lateral y en el breadcrumb (Control Room › Cliente · Proyecto). *(Sospecha: `updateProjectHeader` busca `#breadcrumb` y `.sidebar-project-client/name`; si un selector cambió, tira error y no actualiza.)* | ✅ |
| I3 | ⭐ Autocompletado al elegir empresa **Cliente** | Elige del desplegable una empresa que tenga contacto/mail/teléfono en la BD | Rellena Contacto, Mail y Teléfono del cliente **solo si están vacíos** (nunca pisa lo ya escrito), con toast "Datos completados desde la BD" | ✅ |
| I4 | ⭐ **Empresa cliente (BD)**: vínculo por ID | En "Empresa cliente (BD)" elige una empresa; luego escribe un nombre que no exista | Al elegir una empresa se **vincula por identificador** (no por el nombre visible). Un texto que no calza con ninguna empresa **no cambia** el vínculo y muestra "⚠ Esa empresa no está en la BD: el vínculo no cambió". Si el "Cliente" coincide con una empresa, ofrece el botón "Vincular a «X» (coincide con el nombre)" | ✅ |
| I5 | Combobox **Agencia** + autofill | Escribe/elige una Agencia de la BD | Igual que Cliente: filtra, avisa si no está, y al elegir rellena Contacto/Mail/Teléfono de Agencia solo si vacíos | ✅ |
| I6 | ⭐ **Nombre del proyecto** sincroniza header | Cambia "Nombre del proyecto" | El nombre se actualiza **en vivo** en la barra lateral y el breadcrumb | ✅ |
| I7 | Campos de texto simples | Edita **Productora** y **Servicio** | Se guardan tal cual (sin autocompletado ni sincronización de header) | ✅ |

## B. Derechos de uso del material

| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| I8 | Derechos (tiempo / plataformas / territorio) | Completa los 3 campos de "Derechos de uso del material"; recarga | Los tres se guardan (viven en un bloque anidado del proyecto) y **persisten** al recargar | ✅ |

## C. Contacto del cliente / agencia

| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| I9 | ⭐ Combobox **Contacto** (persona) + autofill | En "Contacto principal" (cliente o agencia) escribe/elige una persona de la BD | Filtra contra la BD de **personas**; al elegir una, rellena Mail y Teléfono **solo si están vacíos**, con toast. Mismo riesgo de delegación de 4 eventos que I1 | ✅ |

## D. Responsables (RECI)

| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| I10 | RECI de solo lectura | Mira Productor Ejecutivo / Director / Jefe de Producción | Son **solo lectura** (no editables aquí): muestran el nombre y, debajo, mail y teléfono desde la BD (o "— Sin datos en BD"). El botón "Gestionar en Cargos →" lleva al módulo **Cargos** | ✅ |
| I11 | RECI se refleja desde Cargos | Asigna/cambia PE, Director o JP en el módulo **Cargos**; vuelve a Info Proyecto | El nombre nuevo aparece aquí (Cargos es la fuente única; Info Proyecto solo lo refleja) | ✅ |

## E. Estado del proyecto

| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| I12 | ⭐ Gate de aprobación (Venta → Preproducción) | Proyecto en Venta con algún problema (fila de Servicios/Talentos con Valor+Cantidad pero sin DTE, **o** Presupuesto Cliente en $0, **o** margen cotizado negativo). Cambia el estado a Preproducción | **No deja aprobar**: modal "No se puede aprobar todavía" listando los puntos a corregir; el selector vuelve al estado anterior; "Ir a corregir" lleva al Presupuesto. *(El gate se dispara desde este selector vía gancho a `updateProjectState`; verificar que corre.)* | ✅ |
| I13 | Aprobar sin bloqueadores + confeti | Proyecto en Venta sin problemas → pasar a Preproducción y confirmar | Sale el modal "¿Aprobar este proyecto?"; al confirmar, se aprueba, **confeti**, y en Presupuesto aparece Costo Real (columnas reales) | ✅ |
| I14 | ⭐ Revertir Preproducción → Venta | Proyecto aprobado; intenta volver el estado a "Venta" **sin** Modo Administrador; luego con Modo Administrador activo | Sin admin: modal "Acción restringida" (requiere administrador) y el selector no cambia. Con admin: modal de confirmación grave; al confirmar, vuelve a Venta, se oculta Costo Real y avisa que fue excepción de administrador | ✅ |
| I15 | Fechas y condiciones de pago | Edita Fecha de cotización/aprobación/entrega/pago y "Condiciones de pago"; recarga | Todas se guardan y **persisten** | ✅ |
| I16 | Badge de estado | Cambia el estado | El badge de abajo refleja el **color y nombre** del estado actual | ✅ |

## F. Zona peligrosa y Papelera

| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| I17 | Zona peligrosa (eliminar proyecto) | Sin Modo Administrador, busca la "Zona peligrosa" al final; luego activa Modo Administrador | Sin admin (o sin permiso de eliminar): la sección **no aparece**. Con admin + permiso: aparece "⚠ Zona peligrosa"; eliminar exige escribir el **nombre exacto** del proyecto para habilitar el borrado (irreversible) | ✅ |
| I18 | Papelera: eliminar → restaurar | Elimina un proyecto; abre la Papelera; restáuralo; recarga | El eliminado aparece en la Papelera con su fecha; "Restaurar" lo devuelve al Control Room y **sobrevive a recargar** (se limpia el borrado en el servidor). Si la Papelera está vacía, avisa | ✅ |

## G. Persistencia general

| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| I19 | ⭐ Todo el formulario sobrevive a recargar | Edita identidad, contactos, derechos, fechas y condiciones; navega a otro módulo y vuelve, y recarga (Cmd+Shift+R) | Todo sigue guardado tal cual. *(Sospecha: los campos de identidad marcan solo "cabecera sucia" sin llamar al guardado directo —igual que en `main`—; si la mudanza rompió el guardado al navegar/recargar, se perderían.)* | ✅ |

**Estados:** ⬜ pendiente · 🔄 probando · ✅ pasó (no re-probar) · ❌ falló (bug abierto) · 🔁 cambió a propósito.

## Notas

- **Resumen financiero — retirado a propósito (no probar):** en `main` había una
  barra de KPIs (Costo cotizado/real/delta/alertas) en Info Proyecto. Por decisión
  de Agustín (V11.5.0) vive **solo** en Presupuesto (fuente única); acá quedó
  oculta. No es bug de migración; no hay prueba asociada.
- **Sospechas prioritarias del cruce (probar primero):**
  - **I1 / I3 / I4 / I5 / I9 — comboboxes:** migraron de handlers inline a
    delegación de 4 eventos (foco / tipeo / salir / elegir). Si un evento no
    dispara, se rompe el filtro, el autocompletado o el vínculo. Candidato #1.
  - **I2 / I6 — sincronía de header:** `updateProjectHeader` toca `#breadcrumb`,
    `.sidebar-project-client` y `.sidebar-project-name`; si un selector cambió en
    la modular, lanza error y el header no se actualiza.
  - **I12 / I14 — cambio de estado:** el selector dispara `updateProjectState` vía
    gancho (la lógica vive en `admin.js`). Verificar que el gate y el bloqueo de
    retroceso realmente corren desde acá.
- **Autofill (I3, I5, I9):** la regla es **solo rellenar campos vacíos**, nunca
  pisar lo escrito. Confírmalo probando con un campo ya lleno.
- Al probar, agrupa los ❌ por familia para armar un solo reporte de bugs (Paso 4)
  y una sola vuelta de fix.

### Cierre vuelta `fix/info-proyecto-arreglos-qa` (2026-07-10) — Grupo 1
Agustín probó las 19. Pasaron todas. Ninguno de los arreglos era regresión de la
mudanza (comportamiento compartido con `main`).
- **I2, I4, I6, I8, I9, I10, I12, I14, I15, I16, I18, I19 → ✅** limpias en la
  primera pasada.
- **I3/I5 → ✅** (fix) el autocompletado de empresa no tenía de dónde copiar (la
  empresa llegaba con contacto/mail/teléfono planos vacíos); `syncLegacyFromContactos`
  ahora los resuelve desde el contacto principal vinculado.
- **I11 → ✅** (fix) asignar un cargo en Cargos ahora sí proyecta PE/Director/JP a
  Info Proyecto (`cargoGuardarModal` llama a `_cargosDerivarRECI`).
- **I13 → ✅** (fix) el borrado de filas vacías al aprobar ahora persiste
  (`purgeEmptyRows` encola el delete al servidor).
- **I17 → ✅** (fix) el Modo Admin re-renderiza el módulo abierto al instante.
- **I1 → ✅** (fix I1b) el aviso "no está en la BD" persiste al re-render.

### Cierre vuelta `feat/info-proyecto-grupo2-mejoras` (2026-07-10) — Grupo 2
Las 4 mejoras probadas y aprobadas por Agustín (varias sub-vueltas):
- **Cargos** · se quitó el cargo **"Productor/a"** del catálogo (queda "Jefe/a de
  Producción").
- **I7** · se sacó el campo **Productora**; **Servicio** pasó a desplegable
  (Producción / Postproducción / Otro especificar).
- **I1a** · el botón "+ Agregar a la BD" abre la **ficha de empresa inline** (reusa
  el editor) en vez de navegar; deja la empresa vinculada.
- **I11b** · al crear proyecto se asignan PE/Director/JP con el **combobox estrella**
  (personas de la BD); quedan como responsables **y como cargo real** en Cargos.
  Ajustes: tipo **interno/externo según los internos reales** (no auto-interno);
  **perfil de acceso por defecto** (PE→Ejecutivo, Director→Creativo, JP→Producción);
  **estado** interno→activo / externo→pendiente; si la persona no está en la BD
  (con correo) el cargo muestra **"Agregar a la BD"** y oculta "Cambiar" (en Cargos
  e Info Proyecto); guardar una persona ahora exige **nombre + correo**; el correo
  del externo se **pre-rellena** al editar el cargo; botón "Gestionar en Cargos"
  en **ámbar**.
  - Dato de base confirmado: la RPC `guardar_cargos` solo hace DELETE+INSERT en
    `project_cargos`, **no crea membresías ni invitaciones**.

**Pendiente · flujo de BD (DESPUÉS de cerrar Info Proyecto, NO en esta skill):**
- Asignar **contacto principal a una empresa no persiste** (teoría: sin columna en
  `companies`; frontend y RLS ok, hay 18 vínculos guardados). Memoria de proyecto
  [[takeos-bd-pendiente-empresa-contacto]].
- **I7 · Servicios configurables:** guardar un servicio "Otro" como **predeterminado**
  y poder gestionarlos en una **pestaña "Servicios"** del perfil de empresa (junto a
  Datos de la empresa / Equipo / Diseño), más el reporte anual por tipo de servicio.
  Todo eso necesita BD → va por el flujo de migraciones.
