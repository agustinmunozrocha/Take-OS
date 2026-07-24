# QA · Legal (`frontend/src/modules/legal.js`)

Referencia de comportamiento: monolito en `main` (`git show main:index.html`).
Genera documentos legales (Cesión de derechos, NDA, contrato) desde **plantillas**,
con ciclo Borrador → Generado → Enviado → Firmado. Persistencia: `legal_documents`
(+ PDF firmado en el bucket privado `documentos-legales`). PDF vía `printViaIframe`.
Cobertura: 2/8 🤖 (gates) + 6 👁 (QA automatizado 2026-07-20, 0 bugs).

> **Alcance:** Legal es un módulo **mayormente 👁 / bloqueado para el QA automatizado**:
> (a) el **contenido legal es provisional** — banner "Documentos preliminares, no usar en
> producción real... no validadas legalmente" (Gate C, los textos definitivos los fija
> Legal, Ley 21.719); (b) **generar un documento requiere una plantilla**, y **crear
> plantillas requiere Modo administrador** (clave de admin, que no tengo). El juez final
> eres tú.

---

| ID | Qué probar | Pasos | Esperado (según `main`) | Estado |
|----|-----------|-------|-------------------------|--------|
| LG1 | El módulo carga | Proyecto → Legal | Muestra el banner de "documentos preliminares", KPIs (firmados / en proceso), filtros (tipo/estado) y el estado vacío | ✅ |
| LG2 | Generar sin plantillas | "+ Generar documento" sin plantillas creadas | Toast "No hay plantillas · Crea una plantilla en Plantillas antes de generar" (gate correcto) | ✅ |
| LG3 | Crear plantilla = Modo admin | Pestaña Plantillas | "🔒 Solo un Administrador puede crear o editar plantillas" (gate) | ✅ (gate verificado por código/UI) |
| LG4 | Generar documento | Con plantilla + contraparte → "Generar" | Crea el documento en estado "Generado"; persiste en `legal_documents` | 👁 (requiere plantilla → Modo admin) |
| LG5 | Ciclo de estados | Generado → "Marcar enviado" → subir PDF firmado → "Firmado" | Avanza Borrador→Generado→Enviado→Firmado; el PDF firmado sube al bucket privado (URL firmada 1 h) | 👁 (requiere un documento generado) |
| LG6 | Eliminar / versionar | "Eliminar" documento; "Guardar nueva versión" | Se elimina / se versiona (no se borra la historia) | 👁 |
| LG7 | PDF del documento | "Ver" / exportar PDF | El PDF se genera y se ve correcto (marca, firmas, estructura) | 👁 (PDF vía printViaIframe — mírala) |
| LG8 | Contenido legal | Leer el texto de Cesión / NDA / contrato | Textos definitivos aprobados (Ley 21.719) | 👁 (Gate C — hoy son provisionales) |

**Estados:** ⬜ pendiente · 🔄 probando · ✅ pasó · ❌ falló · 🔁 cambió a propósito.

## Notas
- **0 bugs.** El módulo carga bien, el banner de preliminar está, y la generación está
  **correctamente gateada**: sin plantillas → toast claro; crear plantillas → Modo
  administrador. El resto del flujo (generar, ciclo de estados, PDF firmado a Storage,
  eliminar/versionar) y el **contenido legal** son 👁: requieren plantillas (Modo admin),
  un documento generado, y los textos legales definitivos (Gate C, Ley 21.719).
  Merece una **pasada dedicada contigo** (con Modo admin activo y las plantillas creadas).
