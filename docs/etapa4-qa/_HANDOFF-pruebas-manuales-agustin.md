# Handoff · Pruebas manuales de Agustín + próximos pasos (Etapa 4)

> **Para la próxima sesión:** Agustín va a correr las pruebas 👁 de abajo. Ayúdalo a
> ejecutarlas (una por una o por bloques), marca ✅/❌ en el catálogo del módulo
> (`docs/etapa4-qa/<modulo>.md`) y, si aparece un bug, entra a **Modo fix** del skill
> `depurar-modularizacion-etapa4` (plan aprobado ANTES de tocar código). Cuando estén
> todas, sigue con "Después de las pruebas" al final.

---

## Dónde estamos (macro)
- **QA de TODOS los módulos: hecho. 0 regresiones de la modularización.** El modular es
  fiel al monolito. Esa era la validación grande de la Etapa 4.
- Se encontraron y **arreglaron 2 bugs de persistencia** (rama ya mergeada a
  `etapa4-integracion`, commit `ffc75e2`):
  1. **Crear proyecto** no persistía si no le ponías PE/Director/JP y no lo editabas.
  2. **Agregar/borrar día de rodaje** no persistía (era el "no persiste en Producción":
     Rodajes es el módulo de esa etapa). Ambos **también están en producción (monolito)**.
- **Nada pusheado aún.** 16 commits locales en `etapa4-integracion`. Comando de push
  al final de este archivo.
- **Faltan:** las pruebas 👁 de abajo + verificar los 2 fixes. Y, para el paso a `main`,
  los gates B (seguridad/RLS real) y C (textos legales) — ver "Camino a main".

---

## 0) PRIMERO: verificar los 2 arreglos de persistencia
| ID | Módulo | Qué hacer | Resultado esperado (✅) |
|----|--------|-----------|------------------------|
| FIX-1 | Kanban | Crea un proyecto y **no le pongas nada** (ni responsables) → Cmd+Shift+R | El proyecto **sigue ahí** |
| FIX-2 | Rodajes | Mueve un proyecto a **Producción**, agrega un día de rodaje, **no toques nada más** → Cmd+Shift+R | El día **sigue ahí** |

---

## 1) Visual / PDF (tu ojo)
| ID | Módulo | Qué hacer | Resultado esperado (✅) |
|----|--------|-----------|------------------------|
| CR13 | Crew | Con crew + externos, "Crew List (PDF)" | PDF "CREW LIST": columnas Rol/Nombre/Teléfono/Mail/Restricción; externos con tag de tipo |
| CR14 | Crew | "Catering (PDF)" | PDF "CATERING"; restricción ≠ "Ninguna" **resaltada en rojo** |
| CR17 | Crew | "Transporte (PDF)" → exportar seleccionados | PDF "TRANSPORTE": solo los marcados; Nombre/Rol/Teléfono/Dirección(link Maps)/Comuna |
| LG7 | Legal | "Ver" / exportar un documento | El PDF se ve bien: marca, firmas, estructura |
| CFG8 | Config | Empresa/Productora → pestaña "Diseño" | Colores y tipografías de marca se ven/editan bien |
| NTF7 | Notificaciones | Pestaña "Plantillas" → editar asunto/cuerpo, B/I/U, variables | Editor rich-text y "pills" de variables funcionan |
| NTF8 | Notificaciones | Cambiar canal email ↔ WhatsApp; mirar el preview | El preview se ve correcto en ambos |
| NTF6 | Notificaciones | Pestaña "Enviar" → seleccionar destinatarios | Botón "Enviar a N": N cuenta solo los que tienen mail+datos; los bloqueados salen listados |

## 2) Modo administrador (ya puedes: NO pide clave, solo actívalo)
| ID | Módulo | Qué hacer | Resultado esperado (✅) |
|----|--------|-----------|------------------------|
| ADM2 | Admin | Con Modo admin, cambiar un proyecto de Producción → **Venta** | Pide confirmación (desbloquea cotización, oculta Costo Real); revierte |
| ADM3 | Admin | Estado → **Cerrado**; luego reabrir | Cierra (histórico); reabrir requiere admin |
| CFG3 | Config | Empresa → "Datos de la empresa 🔒" → editar razón social/RUT/representante → Guardar | Se guarda y **persiste** tras recargar |
| BD35 | BD | Archivar una persona/empresa → "Archivados" → Restaurar | Desaparece de la BD y vuelve al restaurar |
| KB5 | Kanban | Mover un proyecto entre columnas/estados | La tarjeta cambia de columna; el KPI se ajusta; persiste |
| KB10 | Kanban | Dentro del proyecto → "Exportar este proyecto" | Descarga un `.json` de ese proyecto (no toca la BD) |
| LG4 | Legal | Crear una plantilla → "+ Generar documento" | Crea el documento en estado "Generado"; persiste |
| LG5 | Legal | Generado → "Marcar enviado" → subir PDF firmado → "Firmado" | Avanza el ciclo; el PDF firmado sube al bucket privado (link firmado 1 h) |
| LG6 | Legal | "Eliminar" documento / "Guardar nueva versión" | Se elimina / se versiona (no se pierde la historia) |

## 3) Necesitan otro usuario / flujo real
| ID | Módulo | Qué hacer | Resultado esperado (✅) |
|----|--------|-----------|------------------------|
| INV5 | Invitaciones | Abrir un link de invitación **como el invitado** (sesión sin loguear / incógnito) | Se ve "de <productora>", el rol, los términos (Ley 21.719) y el consentimiento |
| INV6 | Invitaciones | Sin marcar el consentimiento | "Aceptar" queda deshabilitado hasta marcar la casilla |
| INV7 | Invitaciones | Marcar consentimiento → "Aceptar" | Copia datos + activa la membresía; entra al proyecto |
| INV8 | Invitaciones | "Rechazar" | La invitación se cierra |
| INV9 | Invitaciones | Revisar el panel personal del **emisor** con invitaciones pendientes | ¿Debe figurar la invitación que TÚ enviaste? (decisión de UX) |
| PF7 | Perfil | Aceptar una invitación con datos incompletos | Aparece el formulario "solo lo que falta"; guarda con el mismo _perfilGuardar |
| TM13 | Tareas | Entrar como **Invitado** (perfil@invitado.com, tareas=L) → intentar crear tarea | Toast "Solo lectura · Tu perfil no puede crear tareas" |
| ADM6 | Admin | Con un perfil ≠ Administrador → intentar Modo admin | "Solo el perfil Administrador puede activarlo" |

## 4) Espejo del Presupuesto (requieren un proyecto en Preproducción/Producción)
| ID | Módulo | Qué hacer | Resultado esperado (✅) |
|----|--------|-----------|------------------------|
| CR1 | Crew | En Presupuesto marca "Conf." a una persona con nombre → abre Crew | Aparece en la tabla; KPI "Personas confirmadas" +1 |
| CR2 | Crew | Marca una fila confirmada como "no va a rodaje" → abre Crew | NO aparece en Crew |
| CR3 | Crew | Misma persona confirmada en 2 roles | Aparece 1 sola vez |
| CR6 | Crew | Confirma un nombre que NO está en la BD | "⚠ Sin BD"; KPI "Faltan en BD" +1 |
| CR7 | Crew | Click en "⚠ Sin BD" / "+ Agregar persona a la BD" | Abre el alta de Persona con el nombre precargado |
| CALC5 | Calculadoras | Doble clic en "Costo real" de una fila con DTE → ingresar monto | Calcula el costo empresa según el DTE (boleta/factura/exenta) |
| CALC6 | Calculadoras | En una fila, abrir "Hora extra" → horas + valor + recargo | `valorHora × (recargo/100) × horas`; defaults: valor fila ÷ 10, recargo 150% |

## 5) Gate C / contenido legal (esperan textos definitivos aprobados)
| ID | Módulo | Qué hacer | Resultado esperado (✅) |
|----|--------|-----------|------------------------|
| ESP8 | Espacio | Abrir cada flujo de "Privacidad y datos" (descargar/revocar/eliminar) | Textos definitivos + comportamiento de cada derecho (Ley 21.719) |
| LG8 | Legal | Leer el texto de Cesión / NDA / contrato | Textos definitivos aprobados (hoy son provisionales) |

## 6) Infra / difíciles de automatizar + estados vacíos
| ID | Módulo | Qué hacer | Resultado esperado (✅) |
|----|--------|-----------|------------------------|
| D8 | Documentos | Adjuntar un archivo > 15 MB | Toast "Archivo muy grande"; no se adjunta |
| D9/D10 | Documentos | Con Storage no disponible, adjuntar ≤600 KB / >600 KB | ≤600 KB cae a base64 ("adjuntado local"); >600 KB "sin nube disponible" |
| D11-D13 | Documentos | Arrastrar 1 archivo / 3 archivos / soltar sobre botones | Crea doc(s) con el adjunto; el drop asciende hasta la zona |
| D15 | Documentos | Doc con adjunto base64 legado → "Abrir ↗" | Decodifica y abre el PDF; revoca el link a los 60 s |
| BD25-31 | BD | Exportar BD → reimportar; plantilla; formatos 3 hojas / 1 hoja; normalización; fusión; sync | Round-trip sin duplicar; normaliza RUT/tel/banco; fusión no destructiva |
| CR4/CR18 | Crew | Proyecto **sin confirmados** → abrir Crew / exportar | Alert "Aún no hay crew confirmado"; export → toast "Sin personas" |
| CG16 | Cargos | Con la org en el tope (12 colaboradores) → "+ Asignar un cargo" | Modal de venta "Tope de colaboradores"; contador N/Max en rojo |

> Detalle prueba-por-prueba y contexto en cada `docs/etapa4-qa/<modulo>.md`. Muchas otras
> pruebas 🤖 ya quedaron ✅ (no re-probar; ver el estado en cada catálogo).

---

## Después de las pruebas (protocolo del skill `depurar-modularizacion-etapa4`)
1. **Si una prueba falla → bug:** junta los bugs por módulo/familia y entra a **Modo fix**
   (branch desde `etapa4-integracion`, **plan aprobado por Agustín ANTES de tocar código**,
   depurar, re-probar, merge `--no-ff`, push origin + force-push staging, marcar ✅/❌).
2. **Cuando todo pase (👁 + los 2 fixes):** el QA de la Etapa 4 queda cerrado y
   `etapa4-integracion` está listo. Aplicar también los **2 fixes de persistencia al
   monolito de `main` (producción)** por su flujo de producción aparte.
3. **Push pendiente de este ciclo** (lo hace Agustín):
   ```bash
   cd ~/Software
   git push origin etapa4-integracion                 # backup (NO despliega)
   git push --force staging etapa4-integracion:main   # deploy a staging (SÍ despliega)
   ```

---

## Camino a `main` (el "corte", Lote 4 — FUERA del skill de depurar)
Pasar Rizora modularizado a `main` = **el modular reemplaza al monolito en producción real**.
Es un paso **deliberado**, no un merge casual, y **no** lo cubre el skill de depurar. Antes de
hacerlo, cerrar/decidir:
- **Gate B (seguridad):** RLS real por organización y rol (reemplazar políticas `mvp_`) +
  pruebas de cruce entre empresas (multi-tenant). **Recomendado cerrar antes de main.**
- **Gate C (legal):** textos de la Ley 21.719 aprobados por abogado (deadline 1-dic-2026) +
  `frame-ancestors` del hosting. Crítico para beta real.
- **Deuda P1 seguridad:** el soft-delete de proyectos desde el cliente debe pasar por la RPC
  `eliminar_proyecto` (hoy elude el permiso en RLS); endurecer aislamiento de `contacts`
  frente a externos.
- **Migraciones pendientes de prod (R4):** al mergear etapa4→main deben viajar las que hoy
  solo están en staging (organization_services, renombrar_servicio, companies_representante_
  duenos, storage_buckets_paridad). Ver `_VUELTA-EN-CURSO.md` / notas de memoria.
- **Los 2 fixes de persistencia** también a `main` (monolito) por su flujo.

**Lectura:** técnicamente el modular ya está validado (0 regresiones). El corte a `main` es
responsable **después** de: (a) tus pruebas 👁 + fixes verificados, (b) Gate B, (c) decisión
sobre Gate C, (d) migraciones alineadas. Agustín arbitra el momento.
