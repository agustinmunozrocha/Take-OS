# CLAUDE.md — TakeOS

> Este archivo son las **instrucciones permanentes** para Claude Code en este repositorio. Vive en la raíz del proyecto; Claude Code lo lee solo al iniciar cada sesión. Es la "biblia de producción" del agente. Mantenerlo corto y de alta señal.
>
> **Versión:** borrador 0.1 · **Mantiene:** Agustín (arbitra) / Redactor (consolida). Cuando suban de versión los canónicos, actualizar las referencias de abajo.

---

## 1. Qué es TakeOS

TakeOS es un **sistema operativo de producción audiovisual**, modelo **proyecto-céntrico**: cada proyecto es la unidad mínima y autónoma (nace, se desarrolla, se cierra y queda bloqueado como fuente histórica). Reemplaza el caos de planillas, mails y WhatsApp con una sola fuente de verdad por proyecto.

Lo construye **Agustín Muñoz Rocha** (Primate Films / La Hectárea SpA), fundador-operador **no-técnico** y **árbitro final** de toda decisión de producto y arquitectura. El software migrará a una sociedad separada como Proveedor SaaS.

## 2. Stack técnico

- **Frontend:** un solo archivo HTML grande (~25.000 líneas) con **JavaScript puro** (sin framework).
- **Backend:** **Supabase** — PostgreSQL (base), Supabase Auth (identidad), Supabase Storage (archivos), RLS + GRANT (acceso) y **RPCs / Edge Functions para la lógica crítica**.
- **Multi-tenant:** `organization_id` en toda tabla de negocio.

## 3. Documentos canónicos (la autoridad)

La verdad del proyecto vive en tres documentos. **Léelos antes de proponer cambios de fondo.** Si un cambio contradice uno de ellos, **levanta la contradicción, no la resuelvas en silencio.**

- **PRD** (`TakeOS_PRD_V3_4.md`) — qué es TakeOS y por qué. **Manda en producto y dominio.**
- **ADR** (`TakeOS_ADR_Backend_v1_6.md`) — cómo se construye técnicamente y por qué. **Manda en lo técnico.**
- **Roadmap** (`TakeOS_Roadmap_Operativo_v1_5.md`) — en qué orden, cuándo y quién. **Manda en ejecución.**

Ante choque: PRD en producto → ADR en técnica → **Agustín arbitra.**

---

## 4. Doctrinas de arquitectura que NUNCA se violan

Estas no se negocian. Si una tarea te empuja a romper una, **detente y avisa**.

1. **Nunca confiar en el cliente** (ADR-001/002/017). El frontend es público y manipulable. La lógica crítica corre **server-side**, tratando todo dato entrante como potencialmente falso.
2. **Regla de oro de dónde va la lógica:** si la operación **mueve plata**, **decide permisos sensibles**, o **debe ser atómica** → **server-side (RPC)**. Si es una lectura o un CRUD simple sobre datos del propio tenant → directo con **RLS**.
3. **Autorización en el servidor, por perfil vía membresía** (ADR-004). Los permisos cuelgan del usuario (membresía interno/externo × perfil), **no del rol por proyecto**. Toda escritura sensible se verifica **dentro del RPC** + RLS. El frontend solo refleja; nunca es la autoridad.
4. **Lógica y tasas tributarias SOLO en la tabla `tax_rates`** (ADR-018), nunca hardcodeadas en el cliente. El cliente las **lee** al iniciar sesión. Cambiar una tasa = **insertar fila nueva** con su `vigente_desde`. **Cualquier hardcodeo tributario en el HTML es un error de severidad alta.**
5. **Modelo relacional, fuente única de verdad** (ADR-005). Relaciones por referencia, **no por copia**. **Soft delete** + campos de auditoría (`created_at`/`updated_at`/`deleted_at`). **GRANT al rol `authenticated` después de CADA tabla nueva** (Supabase no la expone sola; olvidarlo = 403).
6. **Versionar en vez de eliminar; la última manda** (principio 9 / §20). Documentos versionables (cotización, legal, hoja de llamado, plan de rodaje) no se borran. Filas de presupuesto/gastos/tareas/contactos tienen su ciclo propio con soft delete.
7. **El backend recalcula los valores derivados** (ADR-002). Retenciones, totales, etc.: el servidor los recalcula desde los insumos y **rechaza** entradas inválidas (no las "arregla"). La validación en el frontend es **solo UX**.

## 5. Principios de producto que el código debe respetar

(Los diez del PRD §02 — los más operativos para Code.)

- **Proyecto-céntrico:** no existe información huérfana; todo cuelga de un proyecto.
- **Fuente única de verdad:** cada dato se ingresa en un solo lugar y alimenta al resto.
- **Visibilidad de errores:** errores con mensajes claros y accionables; un error oculto es peor que uno evidente.
- **Responsabilidad explícita:** toda tarea tiene un Responsable visible (modelo RECI).
- **Norte anti-cortisol:** las guardas que impiden cometer el error son el norte hecho función. Si un cambio agrega fricción sin reducir un momento de ansiedad del operador, cuestiónalo.

---

## 6. Cómo trabajar en este repo (reglas para Claude Code)

- **Ediciones quirúrgicas.** Cambia **solo** lo pedido. **No toques lo que funciona.** El frontend es un HTML de ~25k líneas: **edita la zona exacta con reemplazos puntuales; NUNCA reescribas el archivo entero.**
- **Tareas chicas y acotadas, una a la vez.** Las mega-tareas no se pueden revisar y se salen de control. Si la tarea es grande, propón dividirla.
- **Explora antes de editar.** Primero encuentra y explica la zona/función relevante; recién después modifica. Usa **Plan Mode** para cualquier cambio no trivial: propón el plan, espera aprobación, luego ejecuta.
- **Pide permiso, muestra el diff, explícate.** Tras cada cambio, muestra qué cambiaste y por qué, en lenguaje simple. Agustín no lee código fluido: la explicación es parte del entregable.
- **No tomas decisiones de arquitectura ni de producto.** Esas son de los chats expertos (BD, permisos, legal…) y de Agustín. Si una tarea requiere esa decisión, **detente y pregunta** en vez de improvisar.
- **Commits frecuentes.** Antes de una tanda de cambios, commit. Si quedó bien, commit. Mensajes claros (son el changelog del código).
- **Idioma:** todo en **español chileno** — código comentado, mensajes de UI, mensajes de commit.

## 7. Convenciones de marca (para PDFs / entregables visuales)

- Tipografías: **Playfair Display** (títulos), **Oswald** (destacados/labels), **Montserrat** (cuerpo).
- Colores: `#121214` (negro), `#343436` (gris oscuro), `#A71E26` (rojo institucional), `#EAE8E1` (base neutra).

## 8. Estado actual y deuda técnica conocida

(Lista móvil — confirmar contra el estado real antes de actuar.)

- **Gate A cerrado:** Firebase apagado y retirado (V10), Supabase Pro con backups validados, `currentUser()` conectado a la sesión real.
- **Autorización en RPCs:** ya construida server-side y fail-closed (Capa 1 + Capa 2). Pendiente de certificación del Test Master.
- **Fixes puntuales pendientes (chat Dev):**
  - Frontend fail-open: `authNivel()` retorna `'E'` cuando no hay acceso cargado → debe retornar `'none'` (fail-closed).
  - `const IVA = 0.19` hardcodeado (~línea 5671) → reemplazar por lectura de `tax_rates`.
  - Mover la generación de IDs (`ctk_`, `emp_`) de cliente a server-side.
  - Validación server-side de cuentas bancarias (formato por tipo de cuenta).

---

*Borrador 0.1 · No es canónico — es el manual de operación del agente. Se versiona y consolida como el resto. Primate Films / La Hectárea SpA.*
