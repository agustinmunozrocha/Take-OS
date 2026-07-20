# QA · Locaciones (`frontend/src/modules/locaciones.js`)

Referencia de comportamiento: monolito en `main` (`git show main:index.html`).
Módulos de apoyo: `dal.js` (persistencia; Plan de Scouting vía `project_scouting`
+ RPC `guardar_operaciones_4a`), `plan-rodaje.js` (motor de tiempos del scouting),
`lib/delegacion.js`. Cobertura: 24/25 ✅ · 1 pendiente 👁 (LOC-16 lightbox/descarga).

> **QA automatizado 2026-07-20 (Chrome MCP, localhost:5173 / etapa4-integracion):**
> las 20 pruebas 🤖 restantes (alta/reutilizar/dedup, estados+KPIs+filtros, quitar
> del proyecto, round-trip de la ficha en la nube, región control vivo, contactos
> con contacto-principal Dueño, fotos al bucket/preview/reordenar/borrar, y el Plan
> de Scouting completo: paradas/traslados, vincular a BD vs libre, cascada de
> tiempos, quiénes van/contacto auto-BD, hora de inicio y ruta en Maps) se
> ejecutaron y **pasaron — 0 bugs, consola limpia**. LOC-20/21/22/23 ya estaban ✅
> (Agustín, BUG-LOC-1/2). Solo **LOC-16** (lightbox ←/→/Esc y "Descargar todo")
> queda 👁 pendiente de la vista de Agustín; el borrar de fotos sí se verificó.
> Las fotos subieron al **bucket real de Supabase Storage** (path + signedUrl).

> **Bugs encontrados y arreglados en esta tanda** (branch
> `fix/locaciones-scouting-persistencia-visita`): BUG-LOC-1 (🔴 el Plan de Scouting
> no persistía a la nube) y BUG-LOC-2 (🟡 se perdió el tiempo de visita por parada).
> Las ⭐ son las de esos bugs: **pruébalas primero**.

---

### A. Repositorio (fichas, estados, fotos)
| ID | Qué probar | Pasos | Esperado (según main) | Estado |
|----|-----------|-------|-----------------------|--------|
| LOC-1 | Agregar locación nueva | Locaciones → + Agregar → Crear nueva → nombre/dirección/comuna/ciudad/región → Agregar | Se crea con estado Candidata, entra al proyecto, abre la ficha, toast "Locación creada" | ✅ |
| LOC-2 | Reutilizar de la BD | + Agregar → Reutilizar de la BD → elegir → Agregar | Entra al proyecto como Candidata sin duplicar la ficha; toast "traída de la BD" | ✅ |
| LOC-3 | Dedup por nombre | Crear nueva con un nombre ya existente | No duplica: reutiliza el registro y abre su ficha | ✅ |
| LOC-4 | Cambiar estado | Ficha → chips Candidata/Confirmada/Descartada | Actualiza el uso, KPIs cambian; solo Confirmadas aparecen en Hoja de Llamado/Plan de Rodaje | ✅ |
| LOC-5 | Filtros del repo | Chips Todas/Confirmada/Candidata/Descartada | Filtra la grilla por estado | ✅ |
| LOC-6 | KPIs | Con varias locaciones y fotos | Locaciones/Confirmadas/Candidatas/Fotos correctos | ✅ |
| LOC-7 | Quitar del proyecto | Ficha → Quitar de este proyecto → confirmar | Sale del proyecto (sigue en la BD), limpia su vínculo en Hoja de Llamado | ✅ |

### B. Datos de la ficha (round-trip)
| ID | Qué probar | Pasos | Esperado (según main) | Estado |
|----|-----------|-------|-----------------------|--------|
| LOC-8 | Editar campos ficha | Cambiar nombre/dirección/comuna/ciudad/región/maps/notas/orientación | Cada cambio se guarda al salir del campo | ✅ |
| LOC-9 | Round-trip nube de la ficha | Editar campos, recargar desde Supabase | Todos los campos reaparecen (incl. maps, orientación, notas, dueño, contactos) | ✅ |
| LOC-10 | Región como control vivo | Cambiar el desplegable de Región | Persiste y muestra la forma canónica (verificar que no quedó control muerto) | ✅ |

### C. Contactos de la locación
| ID | Qué probar | Pasos | Esperado (según main) | Estado |
|----|-----------|-------|-----------------------|--------|
| LOC-11 | Agregar/editar/borrar contacto | Ficha → + Agregar contacto → editar nombre/relación/mail/tel/obs → × | Alta/edición/borrado persisten; valores con comilla se guardan literales | ✅ |
| LOC-12 | Contacto principal (dueño) | Loc con varios contactos | Toma el que dice "Dueño" o el primero | ✅ |

### D. Galería de fotos
| ID | Qué probar | Pasos | Esperado (según main) | Estado |
|----|-----------|-------|-----------------------|--------|
| LOC-13 | Subir fotos | Ficha → + varias imágenes | Comprime y sube al bucket (o cae a local si no hay nube); toast con conteo | ✅ |
| LOC-14 | Preview inmediato | Tras subir | Se ve al toque sin esperar la URL firmada | ✅ |
| LOC-15 | Reordenar (drag) | Arrastrar miniaturas | Reordena; la primera es la Portada; persiste | ✅ |
| LOC-16 👁 | Borrar / Lightbox / Descargar todo | × en foto; click para lightbox (←/→/Esc); ⬇ Descargar todo | Borra de la nube (✅ verificado); el lightbox navega; descarga todas con nombre base_NN.jpg | ⬜ 👁 (borrar ✅) |

### E. Plan de Scouting
| ID | Qué probar | Pasos | Esperado (según main) | Estado |
|----|-----------|-------|-----------------------|--------|
| LOC-17 | Agregar/borrar parada | + Parada varias veces; borrar una | Inserta traslado conector automático; nunca dos paradas ni dos traslados seguidos; borrar parada se lleva su traslado | ✅ |
| LOC-18 | Vincular parada a locación / parada libre | Combobox → elegir de la BD; o texto libre → bola naranja | Vincula (muestra dirección/maps) o crea la locación y la vincula | ✅ |
| LOC-19 | Traslado: tiempo de viaje | Editar el input del traslado | Normaliza y recalcula las horas en cascada | ✅ |
| LOC-20 ⭐ | **Parada: tiempo de VISITA (BUG-LOC-2)** | En una parada, fijar el input "⏱ visita" (p. ej. `030`) | El input **existe**; empuja las horas de las paradas siguientes y el "término aprox." (antes no existía y se ignoraba). Arreglado | ✅ |
| LOC-21 ⭐ | **Cascada con visita + PDF (BUG-LOC-2)** | Con visitas fijadas: revisar la hora de cada parada, el "término aprox." y exportar el PDF de Scouting | Las horas y el término **incluyen** las visitas; la columna "Dur." del PDF muestra la visita de cada parada (antes salía vacía). Arreglado | ✅ |
| LOC-22 ⭐ | **Persistencia del Scouting en la nube (BUG-LOC-1)** | Armar un plan de scouting, guardar, recargar desde Supabase (o abrir en otro dispositivo) | El plan **reaparece** (antes solo vivía en el navegador y se perdía). Arreglado | ✅ |
| LOC-23 ⭐ | **No destruir scouting existente (BUG-LOC-1)** | Proyecto con scouting guardado; editar algo que dispare un guardado; recargar | El scouting **se conserva** (antes cada guardado podía borrarlo en la nube). Arreglado | ✅ |
| LOC-24 | Quiénes van / contacto de parada | + Persona (combobox); contacto y celular de la parada | Chips con typeahead; celular auto desde la BD; bola ● si no está en la BD | ✅ |
| LOC-25 | Hora de inicio / Ruta en Maps | Editar hora de inicio; "Crear ruta en Maps" | Recalcula la cascada; la ruta requiere ≥2 paradas con nombre/dirección | ✅ |

**Estados:** ⬜ pendiente · 🔄 probando · ✅ pasó (no re-probar) · ❌ falló (bug abierto) · 🔁 cambió a propósito.

## Notas

### Bug encontrado y arreglado — BUG-LOC-1 (🔴 bloqueante): el Plan de Scouting no persistía
La migración partió de una versión anterior a que `main` sumara la persistencia del
Plan de Scouting, y `dal.js` quedó **sin nada** de scouting: no lo leía, no lo
guardaba. El plan solo vivía en el navegador (localStorage) y se perdía al recargar
en otro equipo. **Peor:** como la RPC de guardado reemplaza el estado completo, cada
guardado desde la modular **borraba** el scouting que ya estuviera en la nube. Fix:
se restauró el round-trip completo en `dal.js` (leer, aplicar, pedir y mandar
`scouting`), idéntico a `main`. **Sin pendiente de BD:** la tabla `project_scouting`
y la RPC con soporte de `scouting` ya existen en staging **y** en producción (lo
verifiqué en staging). **Verificar en LOC-22 y LOC-23.**

### Bug encontrado y arreglado — BUG-LOC-2 (🟡 molesto): se perdió el tiempo de visita por parada
El input "⏱ visita" de cada parada del Plan de Scouting se había perdido, y el motor
de tiempos ignoraba la visita (solo los traslados sumaban tiempo). Resultado: no se
podía fijar cuánto se queda uno en cada parada, las horas de la cascada salían más
temprano de lo real y la columna "Dur." del PDF quedaba vacía en las paradas. Fix:
se repuso el input de visita, el motor vuelve a sumar la visita y el PDF muestra la
columna. **Verificar en LOC-20 y LOC-21.**
