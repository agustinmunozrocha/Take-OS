# Rizora — Línea Base de Seguridad: OWASP Top 10:2025

**Versión:** 1.7
**Fecha:** 24 de julio de 2026
**Autor de las decisiones:** Agustín Ignacio Muñoz Rocha · Primate Films / La Hectárea SpA
**Responsable técnico de seguridad:** el cargo de **CTO** (hoy VACANTE — modo solo-dev, ADR-027) — el pentest ofensivo es actividad de ese cargo (sobre base consolidada); lo defensivo lo define **Cib,Seg**. Mientras el cargo esté vacante, Agustín asume la responsabilidad con apoyo de las IAs.
**Estado del documento:** Canónico · *hub* transversal de seguridad · alineado al **PRD V3.8** (autoritativo), al **ADR de Backend v1.14**, al **Roadmap Operativo v1.12** y al **Arquitectura y Flujo de Trabajo v1.10**.
**Fuente externa:** OWASP Top 10:2025 — <https://owasp.org/Top10/2025/> · Licencia Creative Commons Attribution 3.0 (CC BY 3.0). Las descripciones de cada categoría están **parafraseadas y adaptadas** a Rizora; no reproducen el texto original.

> **Autoridad documental.** Este documento **no manda sobre el PRD ni sobre el ADR**: es la **referencia de seguridad** (el *hub*) que consumen el **Gate C** (endurecimiento antes del beta externo) y la **actividad de pentest** del cargo de CTO (hoy sin titular). Cuando este documento y el ADR de Backend hablen del mismo control técnico, **manda el ADR**; aquí solo se traduce ese control al lenguaje del estándar y se le pone veredicto. El estado real de cada gate vive en el Roadmap Operativo y en Arquitectura §6.

> **Lo que este documento NO es.** No es un informe de pentest ni una auditoría ASVS completa. Es el documento de **concientización y mapeo**: traduce las 10 categorías del estándar al stack real de Rizora, dice en qué estamos parados sin anestesia, y deja la lista de lo que hay que cerrar. El ataque real (romperlo a propósito) y la verificación fila por fila son trabajo aguas abajo: el **pentest** (actividad del cargo técnico, no chat), y los tests de cruce de tenant del Gate C.

---

## Changelog

### v1.7 — 24 de julio de 2026 (EL CORTE SE HIZO · Gate B CERRADO · el veredicto de A01 se da vuelta)
Consolida el hito del 24-jul: **corte a producción ejecutado** (producción = build modular, rama única `main`, monolito dormido solo como rollback) y **Gate B cerrado**. Verificado contra la base de producción (85 tablas / 173 policies / 28 migraciones) y contra el repo.

- **A01 — de 🔴 a 🟡 (sustancialmente cerrado).** Ya **no existen políticas `mvp_`** (0 en producción): RLS real por organización y rol en las **85/85 tablas** (políticas `b_*` sobre `auth_nivel`/`auth_ve_proyecto`/`auth_codigo_perfil` — SECURITY DEFINER, `search_path` fijo, **fallan cerrado**). **Los tests de cruce de tenant EXISTEN y están en verde**: un admin de otra organización ve **0 filas** de proyectos/contactos/empresas ajenos; un invitado (bd=none) ve 0 contactos. De los dos huecos del 6-jul: **(1) CERRADO — el borrado blando ya NO elude `eliminar_proyecto`**: trigger guard server-side en `projects` (migración `20260724120000`, cláusula `WHEN` sobre `deleted_at`, exige `eliminar_proyecto='E'`; independiente de qué llame el cliente). **(2) SIGUE ABIERTO — el externo lee `contacts`** (ninguna policy mira `memberships.tipo`). Y los **snapshots por org en memoria** quedan **por verificar**. Esos dos son lo que resta de A01.
- **A02 — endurecimiento nuevo: REVOKE de TRUNCATE/TRIGGER/REFERENCES a `anon` y `authenticated`** en todo `public` (migración `20260724121000`): TRUNCATE **no pasa por RLS**; era privilegio residual del GRANT ALL por defecto. Regla operativa: toda migración con CREATE TABLE debe repetir el REVOKE (default privileges lo re-otorgan). El CSP endurecido **ya rige en producción** (llegó con el corte).
- **A08 — el corte a producción está HECHO** (deja de ser el pendiente de integridad del deploy): GitHub Pages en modo `workflow` publica el build de Vite desde `frontend/dist` vía `deploy.yml` (deploy automatizado desde `main`, reemplaza el deploy manual frágil). Las **políticas de `storage.objects` quedaron capturadas en migración** (`20260724122000`) — lo que no está en una migración no es reproducible. Rollback documentado (Pages a `legacy`).
- **A10 — fix de contrato fail-closed en `auth_nivel_org_txt`** (hallazgo del BD Expert): devolvía NULL sin membresía (la canónica `auth_nivel` devuelve `'none'`); con una comparación por negación (`<> 'E'`) un NULL **falla abierto**. Fix: `COALESCE(...,'none')` — CWE-636 cerrado en ese helper.
- **Nuevo control con test que lo vigila:** `supabase/tests/gateB_controles_seguridad.sql` — 5 controles (grants no-DML, guard del soft-delete, 8 políticas de Storage, 0 buckets públicos, contrato no-NULL). **Verde en producción**; correr tras cada deploy en staging y prod. Cierra el ciclo "control sin test se degrada solo".
- **Gate C re-encuadrado:** los **textos legales (Ley 21.719) fueron entregados por los abogados el 24-jul** — el pendiente pasa a ser integrarlos en la app (+ QA). Siguen pendientes: `frame-ancestors`, **A03 cadena de suministro** (SRI, pin `supabase-js`, doble `xlsx`, CI — **no cambió con el corte**; re-auditar sobre el build de Vite), `showToast` sin `escapeHtml` (A05), red async sin `.catch` (A10), alerting (A09).
- **Referencias de versión:** PRD V3.8, ADR v1.14, Roadmap v1.12, Arquitectura v1.10.

### v1.6 — 10 de julio de 2026 (Rizora + modo solo-dev)
- **Renombre a Rizora** en toda la prosa (identificadores técnicos reales conservan nombre — deuda en ADR/Arquitectura).
- **Modo solo-dev (ADR-027) — efecto en la postura.** El cargo de CTO queda vacante. **A03 (separación de funciones):** el "ramas cortas + PR revisado" pasa temporalmente a auto-revisión + `npm run gate` — una **degradación registrada**, no un desmonte; se reactiva al ocuparse el cargo. **Pentest** (era actividad del cargo): en pausa; el mapa de este documento queda listo para cuando se retome. Los roles del ciclo (Cib,Seg define → BD Expert/Code implementa → Cib,Seg verifica → CTO ataca) quedan definidos **por cargo, no por persona**.
- **Referencias de versión:** PRD V3.7, ADR v1.13, Roadmap v1.11, Arquitectura v1.9.

### v1.5 — 8 de julio de 2026 (Informe Técnico de Arquitectura: CSP endurecido en staging, dos huecos nuevos de A01, `npm run gate`)
Consolida el **Informe Técnico de Arquitectura (6-jul, `staging/main` @ `4c8067b`, + addenda 6–8-jul)** y el cierre del handoff de Code de `service_role`. **Recordatorio de eje (ADR v1.12):** producción y staging divergieron 189 commits; los avances de seguridad de abajo son de **staging** salvo que se diga lo contrario, y llegan a producción **con el corte** (ver Arquitectura §5).
- **A05 / A02 — ✅ `'unsafe-inline'` fuera de `script-src` (logrado en staging).** La **delegación de eventos** retiró todos los `onclick` inline, y con eso el CSP de staging quedó en `script-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com` — **sin `'unsafe-inline'`**: el navegador rechaza todo JS inline, propio o inyectado. Era el premio del refactor. Queda `style-src` con `'unsafe-inline'` (deuda "proyecto S"). **Producción sigue con `'unsafe-inline'`** hasta el corte.
- **A03 — showToast como vector de inyección de marcado.** `showToast` inyecta su `body` sin escapar y **13 call-sites le pasan `e.message` del servidor** → marcado/estilo inyectable (no JS, gracias al CSP endurecido). A sanear con `escapeHtml`.
- **A01 — ⚠ dos huecos nuevos de control de acceso (suman al bloqueante del beta).** (1) **Borrado blando que elude el permiso:** `kanban.js` hace `UPDATE` directo de `deleted_at` (autorizado por la policy de `info_proyecto`) en vez de llamar la RPC endurecida `eliminar_proyecto` → un Ejecutivo con `eliminar_proyecto='none'` **igual borra (soft) proyectos** vía PostgREST. Las RPC seguras existen; el frontend no las usa. (2) **"El externo no lee `contacts`" es convención, no invariante:** ninguna policy mira `memberships.tipo`, un externo con perfil 3–6 **lee toda la tabla de contactos**. (3) **Snapshots/airbag no segregan por organización** → restaurar un snapshot de la org A estando en B reintroduce datos cruzados en memoria. Fixes en ADR-024/R4 y §A01.
- **A03 — cadena de suministro (detalle).** Cero SRI en los 3 CDN; `supabase-js@2` con **major flotante** (el runtime de prod puede cambiar sin commit); `xlsx` cargado **dos veces** (eager jsdelivr + lazy cdnjs). Pin exacto + SRI + eliminar la doble carga.
- **A08 — `npm run gate` como integridad de build.** Nace `npm run gate` versionado (`check-inline-handlers` = cero `on*=`; `check-free-idents` = cero identificadores libres). Es el control que faltaba. Pendiente: atarlo a pre-push/CI real (hoy se corre a mano) y sumar un checker de despacho de 2.º nivel.
- **A10 — red async sin fondo.** 35 fire-and-forget + 12 `.then` sin `.catch`, sin handler `unhandledrejection`, y el antipatrón `try { fnAsync(); } catch {}` que aparenta protección sin darla → errores de producción que nadie ve. Falta manejo de excepciones y un `unhandledrejection` global.
- **`service_role` — integridad de build, NO nuevo hueco (A08, no A01).** El cierre de Code (`…140000`) revoca `service_role` en las sensibles: **fidelidad de build** (paridad de ACL con prod), no seguridad — `service_role` ignora RLS por diseño y no sale del servidor. No cuenta como "hueco cerrado" de A01.
- **Referencias de versión:** PRD V3.6, ADR v1.12, Roadmap v1.10, Arquitectura v1.8.

### v1.4 — Junio 2026 (endurecimiento de `anon` completo + patrón canónico)
- **A02 / A01 — endurecimiento de `anon` completo.** La migración previa (`…144834`) solo cubría **7** RPC de escritura. Reconstruyendo staging fiel a prod se detectó que quedaban **19 funciones sensibles** anon-ejecutables tras un reset limpio (**42** vs. **23** en prod). La migración `…120000` (21-jun, ya en producción, no-op de grants) las cierra → **26 funciones sensibles revocadas**. 
- **Patrón canónico documentado:** toda migración que crea o recrea una función sensible en `public` debe hacer `REVOKE ALL … FROM PUBLIC, anon` (no solo `FROM PUBLIC`). **Causa:** Supabase otorga `EXECUTE` a `anon` por *default privileges* como grant **explícito**, que `FROM PUBLIC` no revoca. Detalle en ADR-024.
- **Hueco de reproducibilidad cerrado:** el dump base no capturaba la ausencia del grant de `anon`, así que un reset (staging, preview branch, recuperación) reproducía un estado **menos seguro** que prod. Se cerró con migración (lo que no está en una migración, no es reproducible). Cruza con A08 (integridad del proceso de build/deploy).
- **Recomendación de horizonte:** `ALTER DEFAULT PRIVILEGES … REVOKE EXECUTE … FROM anon` para que las funciones nazcan sin acceso anon (deny-by-default real). Decisión de arquitectura de seguridad, no implementada.
- **Referencias de versión:** PRD V3.6, ADR v1.11, Roadmap v1.9, Arquitectura v1.7.

### v1.3 — Junio 2026 (modularización Vite: efecto en A03 y A05)
- **A03 (Cadena de suministro) — ahora con lockfile y build tool real.** La modularización introdujo **Vite** y un **`package-lock.json`** (antes no había gestor de dependencias ni lockfile). Es un avance parcial de A03: ya existe la base para fijar/escanear dependencias. Las dependencias siguen siendo mínimas (Vite como dev-dependency) y los scripts externos (supabase-js, xlsx) se cargan por CDN (`cdn.jsdelivr.net`) **sin SRI** todavía → el escaneo de dependencias en CI y el SRI siguen pendientes.
- **A05 / A02 — el `'unsafe-inline'` del CSP queda ligado a la modularización.** Hoy el CSP necesita `'unsafe-inline'` **porque** el monolito usa `onclick` y `<script>` inline. La modularización (Etapa 2) es lo que permitirá **quitar `'unsafe-inline'`** —el premio de seguridad real del refactor—. Se registra como objetivo, no como hecho: depende de terminar la Etapa 2 (ver Arquitectura §7).
- **Nota de estado:** la modularización vive en **staging**; producción aún corre el monolito. Esto **no** cambia el veredicto de A01 (el bloqueante sigue siendo el RLS real + tests de cruce de tenant).
- **Referencias de versión:** PRD V3.6, ADR v1.9, Roadmap v1.8, Arquitectura v1.5.

### v1.2 — Junio 2026 (deltas de frontend + cierre del backlog de endurecimiento)
- **A02 / A05 — backlog de endurecimiento ejecutado (migración `…144834`, 17-jun).** Entró como migración (flujo en código): REVOKE de `anon` en las RPC de escritura (los flujos de invitación quedaron anon-ejecutables), `search_path` fijado en ~11 utilitarias y decidida la policy de `app_config`. **Queda solo `frame-ancestors`** (header del hosting). A02 y A05 bajan de "basal cerrada / backlog pendiente" a "**cerradas salvo `frame-ancestors`**".
- **A07 / A01 — el *auth gate* del cliente quedó fail-closed.** `cloudGate` valida la identidad con **`getUser()`** (cierra el fail-open) y `authNivelModulo` **falla cerrado** (devuelve `'none'` para módulos no mapeados) — ambos cerrados V11.15.0. El "punto a vigilar" de A07 (dónde se verifica la sesión) queda **resuelto** para el portero de lectura.
- **A10 — `authNivelModulo` ya falla cerrado** (lo que estaba "a verificar"). **Excepción deliberada, registrada:** los guardas de **escritura** del cliente siguen **fail-open a propósito**, porque la seguridad real de escritura es el RPC `SECURITY DEFINER` (Gate C); no es un hueco, y no debe "arreglarse" por error. Lo que **sigue pendiente** de A10 es **centralizar** el manejo de errores con la modularización Vite.
- **Nomenclatura:** se retira la etiqueta "(Frente D)" del handler `manejarErrorPlan` (recomendación de Dev: nombrar por función, no por letra).
- **A01 sigue siendo el bloqueante real:** el RLS por organización y rol + sus tests de cruce de tenant **no** los cierra esta tanda (son Gate B/C). El cierre del backlog no mueve ese veredicto.
- **Referencias de versión:** confirmadas — PRD V3.6, ADR v1.8, Roadmap v1.7, Arquitectura v1.4 (los documentos hermanos alcanzaron las versiones que este hub ya referenciaba).

### v1.1 — Junio 2026 (integración hub-and-spoke)
- Integrado al **bus de documentos canónicos** como **hub** de seguridad (handoff de Cib,Seg). Se agrega la sección **"Carril y fronteras"** (§0.1) y se confirma que el **Track de Seguridad** es propiedad del **Roadmap** (Gate C), no de este documento: aquí vive el *qué* y el *veredicto*; el *cuándo* vive en el Roadmap.
- **Roster reconciliado:** el rol de seguridad defensiva / estrategia es **Cib,Seg** (define, audita, verifica; mantiene este documento). El **pentest ofensivo es una actividad del cargo de CTO** (hoy sin titular), no un chat. Se retiran las menciones a "Pentester" y "Test Master" como chats.
- **Referencias de versión actualizadas:** PRD V3.6, ADR v1.8, Roadmap v1.7, Arquitectura v1.4.
- Limpieza: se retira la mención residual a `Winterfell` (productora de prueba eliminada de todo registro).

### v1.0 — Junio 2026 (documento nuevo)
- Primera versión. Mapeo completo de las **10 categorías OWASP Top 10:2025** al contexto de Rizora (Supabase/PostgreSQL + RLS + RPC + frontend vanilla JS sobre GitHub Pages, multi-tenant).
- Se ancla cada categoría a los **gates** (A, B, C) y a los ADR relevantes (ADR-001, 002, 003, 004, 005, 010, 011, 012, 014, 023, 024, 025).
- Se registra el **veredicto sin anestesia** (§3) y la conexión con el **backlog de endurecimiento** y el **pentest** (§4).
- Correcciones de estado respecto a notas sueltas: el **XSS ya está cerrado** (función `safeUrl` robusta; no requiere parche, ver Arquitectura §6 y Gate B), y el **motor de organización activa** ya está construido en el cliente (`_setOrgActiva`, V10.9.0). Lo que **no** está cerrado es el **RLS real por organización y rol** + su validación con varias organizaciones.

---

## 0. Cómo leer este documento

### Qué es el OWASP Top 10 y por qué la edición 2025
El **OWASP Top 10** es el documento de concientización más citado del rubro: un consenso amplio sobre los **diez riesgos de seguridad más críticos** en aplicaciones web. No es una checklist exhaustiva ni una certificación; es el "mínimo común" que todo equipo serio debería tener cubierto antes de exponer un producto. La edición **2025** trae cambios reales respecto a 2021, y dos de ellos pegan directo en Rizora:

- **La cadena de suministro de software sube y se amplía** (A03). Ya no es "componentes con vulnerabilidades conocidas": es **todo lo que entra a tu build** (dependencias directas y transitivas, herramientas, el propio pipeline). En un mundo post-gusanos de npm (Shai-Hulud, Glassworm, 2025), un equipo chico que usa npm/Vite y scripts de CDN está expuesto.
- **Aparece una categoría nueva, A10 "Mishandling of Exceptional Conditions"**: el manejo de errores y el principio de **fallar cerrado** (no abrir el acceso cuando algo falla). Esta categoría está hecha a la medida de los riesgos que ya vigilamos en el ADR (fail-closed, transacciones que se revierten enteras).

Otros movimientos relevantes: **Security Misconfiguration sube a A02**, **Cryptographic Failures baja a A04**, **Injection a A05**, e **Insecure Design a A06**. **SSRF dejó de ser categoría propia** y ahora vive dentro de A01 (Broken Access Control). **Logging** ahora se llama "Logging **and Alerting**": registrar sin alertar es media defensa.

### Cómo se conecta con los gates de Rizora
Rizora avanza por **gates** (Roadmap §2). La seguridad de este documento se reparte entre ellos:

- **Gate A — migración con red.** Cerrado. Base "en código" (5 migraciones iniciales; hoy 28), backups, restore validado.
- **Gate B — permisos reales para Primate.** **CERRADO (24-jul-2026).** RLS real por organización y rol en las 85/85 tablas (0 `mvp_`), aislamiento entre organizaciones **verificado** (tests de cruce en verde; test de controles `gateB_controles_seguridad.sql` en producción). El grueso de **A01** quedó cerrado aquí.
- **Gate C — listo para datos de terceros.** Es el **gate crítico antes del beta**, y quedó más corto: **integrar los textos legales ya entregados** (Ley 21.719 — los abogados los entregaron el 24-jul; deadline 1-dic-2026, holgado), el header `frame-ancestors`, los **remanentes de A01** (`contacts` vs externos; snapshots por org), **A03 cadena de suministro** y la alerta mínima de **A09**.

### Cómo está estructurada cada categoría (§2)
Para cada una de las diez:
- **Qué es** — la idea, en una o dos frases, en lenguaje de Rizora.
- **Cómo aparece en Rizora** — dónde podría morder, dado nuestro stack concreto.
- **Estado en Rizora** — dónde estamos parados hoy, sin maquillaje. Citando ADR/Roadmap.
- **Qué hacer** — lo accionable, enganchado a un gate o a un ADR.

### El veredicto de una línea
El backend de Rizora está **bien diseñado** y, desde el 24-jul-2026, **el aislamiento entre productoras es real y está verificado**: RLS por organización y rol en todas las tablas (0 `mvp_`), tests de cruce de tenant en verde (un admin de otra org ve 0 filas ajenas) y un test de controles que vigila que nada se degrade. El viejo bloqueante ("el aislamiento depende de que haya un solo tenant") **quedó cerrado**. Lo que resta antes del beta es acotado: cerrar los dos remanentes de A01 (`contacts` frente a externos; snapshots por org en memoria), integrar los textos legales ya entregados, `frame-ancestors` y la cadena de suministro (A03). Importante — sí; bloqueante estructural — ya no.

### 0.1 Carril y fronteras (quién hace qué con la seguridad)
Para que la seguridad no se pise con el desarrollo, cada actor tiene un carril. El **roster** lo gobierna el **Roadmap §4.2** (dueño del modelo de trabajo entre chats); aquí solo se referencia, para que este documento no decida proceso:

- **Cib,Seg** (dueño de este documento) **mapea, audita y verifica.** Define *qué* hay que endurecer y mantiene el posture OWASP. **No implementa** (eso es BD Expert / Code) ni **ataca** (eso es el cargo de CTO, hoy vacante).
- **BD Expert / Code** **implementan** el hardening como migración o PR (lo que Cib,Seg definió).
- **El CTO** (cargo hoy vacante) **ataca** —el pentest ofensivo es actividad de ese cargo, sobre seguridad ya consolidada— y responde por la seguridad del código. *(Modo solo-dev: la responsabilidad recae en Agustín; el pentest dirigido queda en pausa hasta que el cargo se ocupe o se contrate puntualmente.)*

El ciclo, en orden: **Cib,Seg define → BD Expert/Code implementa → Cib,Seg verifica → (con base consolidada) el CTO ataca.** El *qué* y el *veredicto* viven en este documento; el *cuándo* (la secuencia de cierre) vive en el **Roadmap, Gate C**, como **Track de Seguridad** etiquetado `[SEC] [OWASP A0x]`, trazable 1:1 a la §5 de este documento. Este documento **no** describe ese track ni decide la secuencia: solo dice qué riesgos hay y en qué estado están.

---

## 1. Mapa rápido: las 10 categorías y su prioridad en Rizora

| # | Categoría (2025) | Cambio vs 2021 | Riesgo para Rizora | Estado hoy | Dónde se cierra |
|---|------------------|----------------|--------------------|------------|-----------------|
| **A01** | Broken Access Control | Sigue #1; absorbe SSRF y CSRF | **Alto** — es el corazón del multi-tenant | 🟡 **Sustancialmente cerrado (24-jul):** RLS real por org/rol (0 `mvp_`), tests de cruce en verde, borrado blando cerrado server-side; **quedan** `contacts` vs externos + snapshots por org | Gate B ✅ + Gate C (remanentes) |
| **A02** | Security Misconfiguration | Sube de A05 | **Medio-alto** | 🟢 Backlog ejecutado; **CSP sin `'unsafe-inline'` EN PRODUCCIÓN**; + REVOKE TRUNCATE/TRIGGER/REFERENCES a anon/authenticated (24-jul); solo `frame-ancestors` | Gate C (ADR-024) |
| **A03** | Software Supply Chain Failures | Sube de A06 y se amplía | **Medio** — equipo chico, npm/Vite/CDN | 🟡 Lockfile + Vite + `npm run gate`; falta SRI, pin de `supabase-js`, quitar doble `xlsx` — **no cambió con el corte** | Gate C + horizonte |
| **A04** | Cryptographic Failures | Baja de A02 | **Bajo-medio** — lo gestiona la plataforma | 🟢 Cubierto por Supabase + ADR-011 | Mantenimiento |
| **A05** | Injection (incl. XSS) | Baja de A03 | **Bajo** — RPC parametrizadas, `safeUrl` | 🟢 XSS cerrado; **`'unsafe-inline'` fuera de `script-src` EN PRODUCCIÓN**; `showToast` a sanear | Gate C (ADR-024) |
| **A06** | Insecure Design | Baja de A04 | **Bajo** — diseño explícitamente fuerte | 🟢 ADR como spec; contrato de estado completo | Mantenimiento |
| **A07** | Authentication Failures | Renombrada (era "Identification and…") | **Medio** | 🟡 Supabase Auth; email+pass provisional, Google OAuth destino | Gate B/C |
| **A08** | Software or Data Integrity Failures | Sin cambio de número | **Bajo-medio** | 🟢 Audit inmutable, base en código; **corte HECHO** (deploy automatizado por workflow); Storage capturado en migración; test de controles post-deploy; SRI pendiente | Gate C |
| **A09** | Security Logging **and Alerting** Failures | Renombrada ("Monitoring"→"Alerting") | **Medio** | 🟡 Audit inmutable ✓; **alertas y observabilidad pendientes** | Gate C + horizonte |
| **A10** | Mishandling of Exceptional Conditions | **NUEVA** | **Medio-alto** | 🟡 `authNivelModulo` fail-closed (hecho); **red async sin `.catch`** (35 fire-and-forget); falta centralizar errores | Gate B/C |

Leyenda de estado: 🟢 cubierto / 🟡 parcial / 🔴 sin proceso formal todavía.

---

## 2. Las diez categorías en el contexto de Rizora

### A01:2025 — Control de Acceso Roto (Broken Access Control)
> Sigue siendo el **#1**. En 2025 absorbe SSRF y CSRF. **Relevancia para Rizora: ALTA.** Es, literalmente, el control que define si una productora puede o no ver los datos de otra.

**Qué es.** El control de acceso decide **qué puede hacer cada usuario sobre qué datos**. Cuando falla, alguien lee, modifica o borra lo que no le corresponde, o ejecuta acciones fuera de su nivel. La regla de oro es **denegar por defecto** y que el control viva **en el servidor**, donde el atacante no lo puede tocar. Patrones típicos: referencias directas inseguras (pedir el dato de otro cambiando un `id` en la URL), elevación de privilegios, y APIs de escritura (POST/PUT/DELETE) sin chequeo.

**Cómo aparece en Rizora.** Es el centro de gravedad del multi-tenant. Cada fila de negocio está etiquetada con `organization_id` (ADR-005). La pregunta es: **¿qué impide que el usuario de la productora A lea las filas de la productora B?** Hoy hay dos guardianes posibles —**RLS** (qué filas) + **GRANT** (qué tablas) y las **RPC** (lógica server-side)— y el reparto entre ellos importa. La *publishable key* es **pública** y va al frontend; el ADR-011 lo dice con todas sus letras: esa llave **es segura solo porque hay RLS activo**. Si el RLS no filtra de verdad por tenant, la protección se apoya únicamente en que el acceso pase por RPC y en que **todos los usuarios autenticados sean de confianza** — un supuesto que vale para el equipo interno y se cae con el primer tercero.

**Estado en Rizora.** Honestamente: **parcial**. Lo bueno, y es mucho, está construido:
- Escrituras críticas por **RPC** que validan `auth.uid()` por dentro (ADR-001/004).
- **Motor de organización activa** en el cliente (`_setOrgActiva`, V10.9.0): deriva la organización de la membresía activa y reemplazó el `ORG_ID` fijo, con bandera que tapa el Control Room a quien no tiene empresa.
- **Storage fail-closed**: toda ruta en los 9 buckets **debe** abrir con `{organization_id}/`; sin ese prefijo, el archivo queda inaccesible (ADR-014). Esto es A01 hecho **bien**.
- **`audit_log` inmutable desde el cliente** (ADR-012): se eliminaron las policies abiertas; solo el administrador de la organización lee.

**Actualización 24-jul-2026 — lo que faltaba, YA ESTÁ:** el **RLS real por organización y por rol está implementado y en producción**. No queda ninguna política `mvp_` (0 verificado): las 85 tablas de `public` tienen políticas `b_*` que resuelven por `auth_nivel(módulo, org)` / `auth_ve_proyecto` / `auth_codigo_perfil` — funciones SECURITY DEFINER con `search_path` fijo que **exigen membresía activa y fallan cerrado** (los externos solo ven proyectos donde tienen cargo activo). Y los **tests de cruce de tenant existen y están en verde**: un administrador de otra organización obtiene **0 filas** de proyectos/contactos/empresas/presupuestos ajenos; un invitado (bd=none) obtiene 0 contactos. El aislamiento dejó de ser una promesa: está **verificado y vigilado** por `supabase/tests/gateB_controles_seguridad.sql` (5 controles, verde en producción — correr tras cada deploy).

> **Los huecos del Informe Técnico (6-jul) — estado al 24-jul:**
> 1. **✅ CERRADO — el borrado blando ya NO elude el permiso.** En vez de depender de que el frontend llame la RPC, se cerró **server-side**: trigger guard en `projects` (migración `20260724120000`, `BEFORE UPDATE` con cláusula `WHEN` sobre `deleted_at`) que exige `eliminar_proyecto='E'`. Verificado: un Ejecutivo fabricando el `UPDATE` por PostgREST recibe excepción `takeos_auth`; el flujo del Administrador sigue intacto. Ya no importa qué camino tome el cliente — la autoridad no se puede esquivar.
> 2. **⚠ SIGUE ABIERTO — "el externo no lee `contacts`" sigue siendo convención.** Ninguna policy consulta `memberships.tipo`; un externo con un perfil que tenga `bd∈{E,L}` (p. ej. Creativo, `bd=L`) leería la tabla de contactos completa de la organización. **Fix pendiente:** policy que restrinja `contacts` para `memberships.tipo='externo'` (o lente equivalente). Es el remanente principal de A01.
>
> Además, **A01-adyacente y por verificar:** los **snapshots/airbag en memoria** — confirmar que no reintroducen datos cruzados entre organizaciones al restaurar. Ver Arquitectura §6.

**Qué hacer.**
- ~~Cerrar Gate B (reemplazar las `mvp_`)~~ → **HECHO (24-jul-2026)** y verificado.
- ~~Escribir los tests de cruce de tenant~~ → **HECHOS y en verde**; mantenerlos corriendo tras cada deploy (test de controles).
- **Cerrar el remanente:** policy de `contacts` que mire `memberships.tipo` + verificación de snapshots por org.
- **Recordar que el frontend no protege**: el escenario clásico de A01 es `curl` saltándose el JavaScript. La bandera `_TIENE_EMPRESA` y los chequeos del cliente son **UX**, no seguridad. Toda decisión de acceso debe poder defenderse en el servidor sola.
- **CSRF/CORS**: minimizar el uso de CORS y mantenerlo cerrado a orígenes conocidos. Como las escrituras pasan por RPC con token verificado en cada request (ADR-003), el riesgo de CSRF es bajo, pero conviene confirmarlo en el pentest.
- **SSRF** (ahora dentro de A01): vigilar cuando lleguen las integraciones salientes (Resend, WhatsApp). Cualquier función que haga una request a una URL provista por el usuario es un foco de SSRF.

---

### A02:2025 — Configuración de Seguridad Incorrecta (Security Misconfiguration)
> Sube de A05 a **A02**. **Relevancia para Rizora: MEDIA-ALTA.** Mucho de nuestro stack es servicio administrado; "bien configurado" es la mitad de la seguridad.

**Qué es.** El sistema es inseguro no por un bug de código, sino por **cómo está configurado**: permisos por defecto demasiado abiertos, funciones expuestas que no debían estarlo, headers de seguridad ausentes, mensajes de error que filtran información, cuentas o features de prueba que quedaron prendidas.

**Cómo aparece en Rizora.** En tres capas: (1) **Supabase** —qué función es ejecutable por `anon`, qué policy tiene cada tabla, qué hace el linter de seguridad—; (2) **el hosting** —GitHub Pages y los headers HTTP que podemos o no setear—; (3) **el cliente** —que no filtre llaves ni deje superficie de más.

**Estado en Rizora (actualizado v1.2).** La **lista corta para el beta ya se cerró** (Arquitectura §6): contraseñas filtradas, toggle de registro, OAuth External, CSP, revocación de funciones internas, auditoría dirigida. Y el **backlog de endurecimiento ya se ejecutó** (migración `…144834`, 17-jun, por el flujo en código). Queda **un solo frente**:
- **Backlog de endurecimiento — HECHO (migración `…144834`).** ✅ (a) revocado a `anon` el `EXECUTE` en las **RPC de escritura** como capa externa —cada una valida `auth.uid()` por dentro; **los flujos de invitación quedaron anon-ejecutables**—; ✅ (b) `search_path` explícito fijado en **~11 funciones utilitarias** (esto también cierra el pendiente de A05); ✅ (c) decidida la **policy de `app_config`** (documentada vía COMMENT).
- **Endurecimiento de `anon` — COMPLETO (migración `…120000`, 21-jun).** Reconstruyendo staging fiel a prod se vio que `…144834` solo cubría **7** RPC de escritura: quedaban **19 funciones sensibles** anon-ejecutables tras un reset limpio (**42** vs. **23** en prod). `…120000` las cierra → **26 funciones sensibles revocadas** en total. Ya en producción (no-op de grants). **Patrón canónico** (a respetar siempre que se crea/recrea una función sensible): `REVOKE ALL … FROM PUBLIC, anon`, **no** solo `FROM PUBLIC`. **Causa:** Supabase otorga `EXECUTE` a `anon` por *default privileges* como grant **explícito** que `FROM PUBLIC` no toca. Detalle en ADR-024. *(Recomendación de horizonte: `ALTER DEFAULT PRIVILEGES … REVOKE … FROM anon` para deny-by-default real.)*
- **Privilegios residuales no-DML — CERRADO (migración `20260724121000`, 24-jul).** El GRANT ALL por defecto dejaba a `anon` y `authenticated` con **TRUNCATE/TRIGGER/REFERENCES** sobre todas las tablas de `public` — y **TRUNCATE no pasa por RLS** (un camino de SQL directo vaciaría una tabla ignorando las políticas). Revocados los tres para ambos roles (0 grants restantes, verificado). **Regla operativa nueva:** los default privileges de Supabase re-otorgan estos grants a toda tabla nueva → **cada migración con CREATE TABLE debe repetir el REVOKE**; el test de controles (`gateB_controles_seguridad.sql`, control 1) detecta la degradación y nombra la tabla.
- **Header `frame-ancestors`** (anti-clickjacking): pendiente — **el único frente restante de A02**. **Aquí hay una limitación de plataforma honesta**: GitHub Pages no te deja setear headers HTTP arbitrarios con comodidad. Esto conecta con la decisión de horizonte de mover el hosting a **Cloudflare Pages o Netlify** (per-PR previews + control de headers) — y ahora también con el dominio propio `rizoraapp.com` (registrado 24-jul; hoy con landing). El `frame-ancestors` por meta-tag de CSP es un sustituto parcial; el control real es el header.

**Qué hacer.**
- Cerrar el **backlog de endurecimiento** como migraciones (flujo ADR-023), no como cambios manuales a producción.
- Resolver `frame-ancestors`. Si el hosting actual no lo permite bien, eso es **un argumento más** para ratificar la migración de hosting que ya está en el horizonte.
- **No exponer mensajes de error crudos al cliente** (esto es también A10): un error de base de datos con el detalle completo es reconocimiento gratis para un atacante.

---

### A03:2025 — Fallas en la Cadena de Suministro de Software (Software Supply Chain Failures)
> Sube de A06 y **se amplía**: ya no es solo "componentes vulnerables", es **todo el pipeline**. Fue **#1 en la encuesta de la comunidad**. **Relevancia para Rizora: MEDIA**, y subiendo con la modularización Vite.

**Qué es.** Compromisos en el **proceso de construir, distribuir o actualizar** el software: una dependencia (directa o **transitiva**) que trae código malicioso, una herramienta de build comprometida, un pipeline con menos seguridad que lo que despliega. 2025 lo subió por los gusanos de npm: **Shai-Hulud** (primer gusano auto-propagante de npm, post-install que roba tokens y se replica), **Glassworm**, **PhantomRaven**. El mensaje del estándar es directo: **el desarrollador mismo es ahora el blanco**.

**Cómo aparece en Rizora.** Desde el corte (24-jul), el frontend de producción es el **build de Vite** — o sea `npm` con su árbol de dependencias **transitivas** ya es parte del artefacto servido. Cada `npm install` es una superficie. Además: los **scripts de CDN** que carga el shell (`supabase-js`, `xlsx`) siguen **sin verificación de integridad**, y el **propio repositorio + el workflow de GitHub Pages** son parte de la cadena.

**Estado en Rizora (actualizado v1.3).** **Proceso parcial, recién arrancando.** La modularización ya introdujo **Vite** y un **`package-lock.json`** (commiteado): existe la base para fijar/escanear dependencias, y por ahora el árbol es **mínimo** (Vite como `devDependency`; `package.json` con `type: module`). Lo que **sigue faltando**: el **escaneo automático** de dependencias (Dependabot / `npm audit` en CI) y el **SRI** en los scripts de CDN (`supabase-js` y `xlsx` se cargan desde `cdn.jsdelivr.net` **sin** `integrity`). No hay SBOM. **La buena noticia** es estructural y ya está decidida: **el frontend se trabaja en Code con ramas cortas y Pull Request revisado** (protocolo del cargo técnico; en modo solo-dev, auto-revisión + `npm run gate` — ADR-027). Esto importa porque OWASP nombra exactamente este control: *ninguna persona debería poder escribir código y promoverlo a producción sin la supervisión de otro ser humano* (**separación de funciones**). El flujo de a dos con PR **es** ese control. Falta formalizar el resto.

**Qué hacer.**
- ~~Committear el `lockfile`~~ → **HECHO** (`package-lock.json` commiteado). Mantener la disciplina: las versiones se eligen, no se dejan flotar.
- **Escaneo de dependencias** automático (Dependabot de GitHub, o `npm audit` en CI, o `retire.js`). Suscribirse a alertas de las librerías que se usan.
- **SRI (Subresource Integrity)** en todo script cargado desde CDN: el atributo `integrity` hace que el navegador rechace el archivo si fue alterado. Mejor aún: **bundlear** las dependencias con Vite y dejar de depender de CDN para lo crítico.
- **Endurecer la cadena**: MFA en GitHub, no commitear secretos, proteger la rama principal, mantener actualizadas las herramientas de desarrollo (incluido el propio Claude Code y las extensiones del IDE — son parte de la cadena según el estándar 2025).
- A futuro (horizonte): **SBOM** generado en CI (OWASP CycloneDX/Dependency-Track) cuando el proyecto lo amerite. No es para hoy, pero queda anotado.

---

### A04:2025 — Fallas Criptográficas (Cryptographic Failures)
> Baja de A02 a **A04**. **Relevancia para Rizora: BAJA-MEDIA**, porque casi todo lo gestiona la plataforma.

**Qué es.** Datos sensibles que viajan o se guardan **sin la protección criptográfica adecuada**: sin TLS, con cifrado débil, con llaves mal gestionadas, o guardando en texto plano lo que no debería.

**Cómo aparece en Rizora.** Datos personales (RUT, datos bancarios en `user_bank_accounts`), credenciales, y el `audit_log`. La pregunta es cómo viajan (tránsito) y cómo se guardan (reposo), y dónde están las llaves.

**Estado en Rizora.** **Cubierto** por diseño (ADR-011): **TLS en tránsito**, **cifrado en reposo con llaves gestionadas por la plataforma**, mínimo privilegio, minimización, y **no loguear secretos** (el `audit_log` no guarda datos bancarios ni credenciales en texto plano). El manejo de llaves está bien planteado: la *service_role* / secret key **nunca** va al frontend ni a chats; solo la *publishable key* es pública. Las contraseñas las hashea **Supabase Auth**, no nosotros — que es lo correcto.

**Una nota técnica heredada** (relevante a A04 y A08): `pgcrypto.digest` **no resuelve** bajo `search_path=public`, por eso los hashes de integridad en RPC (p. ej. el de `exportar_mis_datos`) usan `md5()`. **Ojo**: `md5` sirve como **checksum de integridad/detección de corrupción**, no como protección criptográfica contra manipulación deliberada. Para integridad-anti-tampering real, el camino es `pgcrypto` con `search_path` explícito (que de paso es lo que pide el backlog de A02), o una firma. Mientras el hash sea solo "¿se corrompió el export?", `md5` está bien; si alguna vez se usa para "¿alguien lo alteró a propósito?", no alcanza.

**Qué hacer.**
- Mantener. La postura es correcta.
- Cuando se cierre `search_path` en las utilitarias (backlog A02), **reevaluar si algún hash de integridad debería pasar de `md5` a `pgcrypto`**, según para qué se use.
- Confirmar que ningún dato sensible nuevo (futuras integraciones) termine en logs o en mensajes de error.

---

### A05:2025 — Inyección (Injection)
> Baja de A03 a **A05**. Incluye **XSS** (que se fusionó en Injection desde 2021). **Relevancia para Rizora: BAJA**, gracias a decisiones ya tomadas.

**Qué es.** Datos no confiables que el sistema interpreta como **código o comando**: SQL injection (concatenar entrada del usuario en una consulta), XSS (inyectar HTML/JS en la página que ven otros), inyección de comandos. La defensa es **parametrizar** (consultas con parámetros, no concatenación) y **escapar/sanitizar** la salida.

**Cómo aparece en Rizora.** Dos focos: (1) **SQL** — las RPC reciben datos del cliente y arman operaciones; (2) **XSS** — el frontend vanilla JS pinta datos del usuario en el DOM (nombres de proyecto, datos de contactos, etc.) y maneja URLs.

**Estado en Rizora (actualizado v1.2).** **Bueno.** El **XSS ya está cerrado**: la función **`safeUrl` es robusta** y, según Arquitectura §6 y el estado del Gate B, **no requería parche** — esto es importante anotarlo porque circuló como pendiente y **no lo es**. En SQL, las escrituras pasan por RPC; el patrón correcto (parámetros, no concatenar entrada cruda) es la norma del backend. **El pendiente conectado** —de configuración más que de inyección activa— ya se **cerró**: el **`search_path` explícito** quedó fijado en las **~11 funciones utilitarias** (migración `…144834`, 17-jun; backlog ADR-024). Un `search_path` no fijado en una función `SECURITY DEFINER` es un vector clásico de escalamiento (alguien crea un objeto malicioso en un esquema que la función resuelve antes que el esperado); por eso era endurecimiento real, y ya está hecho.

> **✅ Actualización v1.7 — `'unsafe-inline'` fuera de `script-src` EN PRODUCCIÓN (24-jul).** La defensa en profundidad contra XSS dio un salto: la **delegación de eventos** (ADR-026) retiró todos los `onclick`/`<script>` inline, y con el **corte a producción** ese CSP endurecido pasó a regir **en el sitio real**: `script-src` **sin `'unsafe-inline'`** — **aunque una inyección de XSS lograra colar un `<script>` inline, el navegador lo rechaza**. Era el premio de seguridad de toda la modularización, y ya está cobrado. Queda `style-src` con `'unsafe-inline'` (deuda "proyecto S").
> **⚠ Nuevo a sanear (A05, hallazgo del Informe):** `showToast` inyecta su `body` **sin escapar**, y **13 call-sites le pasan `e.message` del servidor**. No permite JS (el CSP endurecido lo bloquea), pero sí **marcado/estilo inyectable**. Fix: pasar el `body` por `escapeHtml`.

**Qué hacer.**
- ~~Cerrar `search_path` en las utilitarias como migración~~ → **HECHO** (migración `…144834`, backlog de A02/A05 a la vez).
- Mantener la disciplina de **parámetros, nunca concatenación** en toda RPC nueva.
- Al pintar datos del usuario en el DOM en los módulos nuevos: seguir usando los helpers seguros (`safeUrl` y equivalentes), no `innerHTML` con datos crudos. La modularización Vite es buen momento para que esto sea una convención de `frontend/src/lib`, no una decisión caso a caso.
- ~~Objetivo de fondo (v1.3): quitar `'unsafe-inline'` del CSP~~ → **LOGRADO Y EN PRODUCCIÓN (24-jul-2026).** La modularización terminó, el corte se hizo, y el CSP de producción quedó sin `'unsafe-inline'` en `script-src`. Queda `style-src` (proyecto S).

---

### A06:2025 — Diseño Inseguro (Insecure Design)
> Baja de A04 a **A06**. **Relevancia para Rizora: BAJA**, y por una buena razón: el diseño es explícitamente el punto fuerte del proyecto.

**Qué es.** Fallas que están en el **diseño**, no en la implementación: ausencia de modelado de amenazas, de límites de negocio, de patrones seguros desde el principio. No se arregla con un parche; se arregla diseñando distinto. Por eso el estándar empuja **threat modeling** y **revisión de diseño seguro** en la fase de diseño.

**Cómo aparece en Rizora.** En las decisiones de fondo: ¿se modeló el aislamiento por tenant? ¿los límites de plan se imponen donde no se pueden saltar? ¿el contrato de las RPC evita estados inconsistentes?

**Estado en Rizora.** Esta es de las pocas donde el veredicto es **sólido sin asteriscos**, y está documentado: *"el backend no es el problema; en su diseño, está esencialmente terminado y bien pensado"* (Arquitectura §1). Evidencia concreta:
- **El prototipo/ADR es spec ejecutable**: las decisiones se escriben antes de construir.
- **Contrato de RPC de estado completo**: las RPC de escritura per-proyecto **reemplazan todo siempre**; el cliente manda el estado completo en cada llamada, sin guardados parciales que dejen mitad de transacción. Esto previene por diseño una familia entera de inconsistencias.
- **Enforcement de planes** modelado en la base (`plan_features`, `rpc_assert_plan`, `rpc_assert_cupo_*`), con guardas en las RPC — los límites se imponen donde el cliente no los puede saltar.
- **Lógica tributaria en la base, nunca en el cliente** (ADR-018); **inmutabilidad financiera al cierre** modelada (ADR-025).
- **Aislamiento por tenant diseñado desde el día uno** (el dato ya está etiquetado; lo que falta es la maquinaria, no el modelo).

**Qué hacer.**
- Mantener la práctica de **decidir en el ADR antes de construir**.
- Hacer **threat modeling explícito** del flujo multi-tenant cuando se cierre el Gate B (no asumir; dibujar quién puede tocar qué y buscar el agujero antes que el pentester).
- Cuidar que la deuda conocida de ADR-025 (`frozen` no es realmente inmutable → futura RPC `cerrar_proyecto`) no se quede en deuda: el diseño contempla el cierre real, hay que construirlo.

---

### A07:2025 — Fallas de Autenticación (Authentication Failures)
> Renombrada (era "Identification and Authentication Failures"), se mantiene en **A07**. **Relevancia para Rizora: MEDIA.**

**Qué es.** Debilidades en **confirmar quién es el usuario**: contraseñas débiles permitidas, falta de protección contra fuerza bruta, sesiones que no expiran o no se invalidan, ausencia de MFA donde corresponde, tokens mal gestionados.

**Cómo aparece en Rizora.** Todo pasa por **Supabase Auth**. Hoy conviven **email+contraseña** (provisional) y **Google OAuth** (destino confirmado, ADR-003). El token **viaja y se verifica en cada request** (stateless) — ese es el principio correcto.

**Estado en Rizora.** **Razonable, con el destino claro.** Lo bueno: Supabase Auth gestiona el hashing y el flujo; el email es el **único criterio de identity linking** (ADR-003, no RUT ni teléfono); se cerró el tema de contraseñas filtradas y el toggle de registro (basal del beta). Google OAuth como destino es la decisión correcta para el rubro. **El punto a vigilar** —y aquí está el cruce con A10— era **dónde se verifica la sesión**: el principio del ADR es verificar el token **en el servidor en cada request**. **Actualización v1.2:** el portero de autorización del cliente (`cloudGate`) ya valida con **`getUser()`** (cierra el fail-open, V11.15.0), así que la fuente de verdad de "quién eres" es el servidor, no un estado cacheado que el usuario pueda manipular. **Excepción deliberada y registrada:** los guardas de **escritura** del cliente siguen **fail-open a propósito**, porque la seguridad real de escritura es el RPC `SECURITY DEFINER` (Gate C) —el portero del cliente es UX, no la cerradura—; no es un hueco y no debe "arreglarse" por error. Esto se cruza con `authNivelModulo`, que ya **falla cerrado** (ver A10).

**Qué hacer.**
- **Agregar Google como proveedor** en Supabase Auth (es configuración, no rearquitectura) y dejar email+contraseña como camino secundario o retirarlo según se decida.
- Confirmar **expiración y rotación de tokens** sensatas, y que el logout invalide la sesión del lado servidor.
- Verificar en el pentest que **ninguna decisión de autorización dependa solo de la sesión cacheada en el cliente**.
- **MFA**: hoy probablemente sobredimensionado para el mercado objetivo, pero queda anotado como horizonte para cuentas de administrador de organización (las que más daño hacen si caen).

---

### A08:2025 — Fallas de Integridad de Software o Datos (Software or Data Integrity Failures)
> Se mantiene en **A08**. **Relevancia para Rizora: BAJA-MEDIA.**

**Qué es.** Confiar en código, actualizaciones o datos **sin verificar su integridad**: instalar una actualización no firmada, deserializar datos no confiables, un pipeline de CI/CD que despliega artefactos manipulables. Es primo de A03 (cadena de suministro) pero se enfoca en la **verificación de integridad**.

**Cómo aparece en Rizora.** Tres puntos: (1) la **integridad de los datos** que exportamos/guardamos (el hash del export de datos personales); (2) la **integridad del código** que desplegamos (¿el build que publica el workflow en GitHub Pages es el que revisamos en el PR?); (3) los **scripts de terceros** que carga el frontend.

**Estado en Rizora.** **Bien encaminado.**
- **`audit_log` inmutable desde el cliente** (ADR-012): trigger `SECURITY DEFINER`, policies abiertas eliminadas. Integridad de la evidencia: ✓.
- **`data_consents` append-only e inmutable** (ADR-020), con copia exacta del texto aceptado. Integridad legal: ✓.
- **Base en código** (ADR-023): el esquema es reproducible desde migraciones versionadas, no un estado vivo irrecuperable. Esto es integridad de la infraestructura: ✓ — y era *"el mayor riesgo silencioso del proyecto"* antes de cerrarse.
- **Hash de integridad** en el export (`md5`): detecta corrupción del archivo (ver nota en A04).

**Avance v1.5 — `npm run gate` (compuertas de integridad de build).** Nace `npm run gate` versionado: `check-inline-handlers` (verifica **cero `on*=`**, o sea que la delegación no se rompa y el CSP endurecido siga válido) y `check-free-idents` (**cero identificadores libres**, la clase de error que tumba la app en runtime). Es el primer control **automatizado** de integridad del artefacto de frontend (antes los invariantes vivían en mensajes de commit y se revisaban a ojo). **Pendiente:** atarlo a un **pre-push/CI real** (hoy se corre a mano) y sumar un checker de despacho de 2.º nivel (los mapas `_*_FN` no tienen compuerta).

**Avance v1.7 — la integridad del deploy quedó resuelta con el corte (24-jul):** el **deploy es automatizado y reproducible** — GitHub Pages en modo `workflow` publica el build de Vite (`frontend/dist`) vía `deploy.yml` en cada push a `main`; se acabó el deploy manual frágil y la divergencia de ramas (rama única). Además, las **políticas de `storage.objects` quedaron capturadas en migración** (`20260724122000`) — antes vivían solo "a mano" en la BD y un rebuild no las reproducía. Y el **test de controles** (`gateB_controles_seguridad.sql`) vigila post-deploy que los controles no se degraden. **El pendiente restante** son los **terceros**: no hay **SRI/firma** en los scripts de CDN (cruza con A03).

**Qué hacer.**
- **SRI** en scripts de CDN (mismo ítem que A03) — o bundlearlos con Vite y salir del CDN para lo crítico.
- ~~Reducir la fragilidad del deploy manual~~ → **HECHO** (workflow de Pages desde `main`).
- Mantener firmados/versionados los artefactos cuando exista CI real; correr el test de controles tras cada deploy.

---

### A09:2025 — Fallas de Registro **y Alerta** de Seguridad (Security Logging and Alerting Failures)
> Renombrada: "Monitoring" → "**Alerting**". El cambio de palabra es el punto. **Relevancia para Rizora: MEDIA.**

**Qué es.** No solo **registrar** los eventos de seguridad, sino **alertar** sobre ellos a tiempo. Registrar sin que nadie (ni nada) reaccione a los patrones de ataque es media defensa. El estándar pide: loguear los fallos de control de acceso y de autenticación, **alertar ante patrones** (p. ej. fallos repetidos), y tener observabilidad que detecte un ataque en curso.

**Cómo aparece en Rizora.** Tenemos un buen **registro** (`audit_log`). La pregunta de 2025 es: **¿quién o qué se entera cuando algo anómalo pasa?** ¿Hay alerta si un usuario falla 50 veces un acceso? ¿Si una RPC se llama a una tasa absurda?

**Estado en Rizora.** **La mitad buena está; la mitad nueva no.**
- **Logging**: el `audit_log` está construido, es inmutable y dirigido (solo el admin de la organización lee). ✓.
- **Alerting + observabilidad**: **pendiente, y explícitamente anotado como deuda** ("la observabilidad —logs/métricas/alertas— sigue pendiente", ADR-014/staging). Hoy no hay alertas automáticas sobre fallos repetidos ni sobre tasas anómalas.

**Qué hacer.**
- **Definir qué dispara una alerta** antes del beta: fallos de autenticación repetidos, fallos de autorización (intentos de cruce de tenant — que se loguean cuando el RLS real esté), llamadas a RPC fuera de rango. No tiene que ser sofisticado; tiene que existir.
- **Rate limiting** en las RPC y en el acceso (esto cruza con A01 y A10): limitar reduce el daño del tooling automatizado y de la fuerza bruta.
- Aprovechar lo que da Supabase (logs del proyecto) y conectar una alerta mínima. La observabilidad seria es horizonte; **una alerta básica sobre eventos de seguridad es Gate C**.

---

### A10:2025 — Mal Manejo de Condiciones Excepcionales (Mishandling of Exceptional Conditions)
> **Categoría NUEVA en 2025.** **Relevancia para Rizora: MEDIA-ALTA**, y es casi un espejo de principios que ya vigilamos.

**Qué es.** Lo que pasa cuando el software **no previene, no detecta o no responde bien** a situaciones anormales: errores no manejados, validación incompleta, y —el corazón de la categoría— **fallar abierto** (*failing open*): cuando algo falla, el sistema **concede** el acceso en vez de negarlo. El CWE estrella es **CWE-636: Not Failing Securely ('Failing Open')**. El estándar es tajante en dos cosas: (1) si estás a mitad de una transacción y algo falla, **revierte todo y empieza de nuevo** (*fail closed*) — intentar recuperar a media transacción es donde se crean los errores irreparables; (2) **manejo de errores centralizado**: una sola forma de manejar excepciones, igual cada vez, no una función distinta por módulo.

**Cómo aparece en Rizora.** Tres focos: (1) los **gates de autorización del cliente** (¿qué hacen ante un error o una caché vacía? ¿niegan o conceden?); (2) las **transacciones de base de datos** (¿se revierten enteras ante un fallo a mitad de camino?); (3) los **mensajes de error** (¿filtran detalle del sistema al usuario? — cruza con A02).

**Estado en Rizora (actualizado v1.2).** **El invariante de lectura ya falla cerrado; queda centralizar errores.**
- **A favor**: el principio de **fail-closed ya es doctrina** en el storage —sin prefijo `{organization_id}/`, el archivo es inaccesible (ADR-014)—; y el **patrón de pruebas SQL en transacción revertida** (`RAISE` al final para hacer rollback) **es exactamente** el "fail closed / revierte todo" que pide el estándar.
- **Resuelto (V11.15.0)**: `authNivelModulo` **falla cerrado** — devuelve `'none'` para módulos no mapeados, en vez de conceder por defecto. Cierra el anti-patrón CWE-636 en el gate de **lectura** del cliente. **Excepción deliberada y registrada:** los gates de **escritura** del cliente siguen **fail-open a propósito**, porque la cerradura real de escritura es el RPC `SECURITY DEFINER` (Gate C). Es una decisión de diseño, no un descuido: el portero del cliente es UX; la seguridad vive en el servidor. **No "arreglar" esto** convirtiéndolo en fail-closed sin entender que rompería la UX sin agregar seguridad.
- **Resuelto (24-jul-2026) — contrato no-NULL en los helpers de autorización.** Hallazgo del BD Expert al revisar el Gate B: `auth_nivel_org_txt` (helper de las políticas de Storage) devolvía **NULL** sin membresía, mientras la canónica `auth_nivel` devuelve `'none'`. Con las políticas actuales (`= 'E'` / `IN ('E','L')`) el NULL denegaba —falla cerrado por suerte—, pero usada con una **negación** (`nivel <> 'E'`, exactamente el patrón del guard del soft-delete) un NULL hace que el chequeo **no dispare: fail-open silencioso** (CWE-636 de libro). Fix: `COALESCE(...,'none')`; el contrato "las funciones de nivel NUNCA devuelven NULL" quedó vigilado por el control 5 del test `gateB_controles_seguridad.sql`. Lección canónica: **dos funciones de autorización con contratos distintos son un agujero esperando a que alguien asuma que se comportan igual.**
- **A centralizar (pendiente)**: con la modularización Vite, definir **un solo manejador de errores**. Esto ya tiene un precedente bueno en producto: el handler central **`manejarErrorPlan(err)`** para los límites de plan (V11.16.0). Esa idea —un punto único, tono sobrio— es la que A10 pide para **todos** los errores, no solo los de plan.
- **⚠ Hallazgo del Informe Técnico (v1.5) — red async sin fondo.** El análisis contó **35 llamadas fire-and-forget + 12 `.then` sin `.catch`**, sin handler global `unhandledrejection`, y el antipatrón `try { fnAsync(); } catch {}` que **aparenta protección sin darla** (el `catch` no atrapa el rechazo de la promesa). En la práctica, un error de red en producción = una consola que nadie mira, sin degradación controlada. Es A10 puro: no detectar ni responder a la condición excepcional. **Fix:** `.catch` en cada async con efecto de UI, un handler `unhandledrejection` global, y retirar el antipatrón. *(Es el mismo mecanismo de "falla en silencio" que produjo los bugs de identificador libre que `npm run gate` ahora ataca — ver ADR-026.)*

**Qué hacer.**
- ~~Empezar por `authNivelModulo`~~ → **HECHO** (falla cerrado, V11.15.0). Queda **auditar el resto** de los gates de autorización y confirmar que fallan **cerrado** (recordando la excepción deliberada de los gates de escritura del cliente, cuya cerradura es el RPC).
- **Confirmar rollback completo** en toda RPC multi-paso: ante error a mitad, se revierte todo. El patrón de testing ya lo encarna; verificar que el código de producción también.
- **No filtrar errores crudos al cliente**: mensaje entendible al usuario, detalle al log (y, si aplica, a la alerta de A09). Un error de base con stack completo es reconocimiento para un atacante (escenario clásico de A10).
- **Centralizar el manejo de errores** en `frontend/src/lib` durante la modularización: una sola forma, no una por módulo. Extender la lógica de `manejarErrorPlan` a un handler general.
- **Límites y cuotas** (rate limiting, quotas): nada debería ser ilimitado. Previene la condición excepcional antes de que ocurra (cruza con A01 y A09).

---

## 3. Veredicto sin anestesia

**Lo que está genuinamente fuerte** (y no es por quedar bien):
- **Diseño (A06)**: el backend está bien pensado y documentado antes de construirse. No hay que reescribirlo; hay que ordenarlo y endurecerlo. Esto es raro y vale oro.
- **Criptografía (A04)** e **integridad de datos básica (A08)**: la plataforma hace lo correcto y el proyecto no se mete a inventar criptografía propia. Audit y consentimiento inmutables. Base en código.
- **Inyección (A05)**: XSS cerrado de verdad, RPC parametrizadas. Esto suele ser un foco de dolor en proyectos jóvenes y aquí está controlado. **Y desde el corte (24-jul), en producción: `'unsafe-inline'` fuera de `script-src`** — el CSP rechaza JS inline aunque una inyección lo cuele.
- **Control de acceso (A01) — el grueso, desde el 24-jul:** RLS real por organización y rol en todas las tablas (0 `mvp_`), aislamiento **verificado** con tests de cruce en verde, borrado blando cerrado server-side, y un test de controles que vigila que nada se degrade. Lo que era el bloqueante estructural del proyecto quedó cerrado y con evidencia.

**Los riesgos que sí importan antes del beta externo**, en orden:
1. **A01 (remanentes) — `contacts` frente a externos + snapshots por org.** El aislamiento entre organizaciones ya es real y verificado, pero "el externo no lee `contacts`" **sigue siendo convención**: ninguna policy mira `memberships.tipo`, así que un externo con perfil `bd=L` leería la base de contactos completa de la organización que lo invitó. Y los snapshots en memoria están **por verificar**. Son los dos caminos que quedan por sellar de A01 — acotados, con fix conocido.
2. **A03 — formalizar la cadena de suministro (no cambió con el corte).** Equipo chico + npm/Vite + CDN en un año de gusanos de npm. Sigue faltando el control automatizado (SRI, pin de `supabase-js`, quitar la doble carga de `xlsx`, escaneo en CI) — re-auditar sobre el build de Vite ahora que es lo que se sirve.
3. **A10 — sanear la red async y centralizar errores.** `authNivelModulo` y los helpers de nivel ya fallan cerrado (incl. el fix `COALESCE` del 24-jul); faltan los `.catch`, el handler `unhandledrejection` global y el manejador central.
4. **A02 — `frame-ancestors`** (único frente restante; conecta con la decisión de hosting/dominio) **y A09 — la alerta mínima.**
5. **Gate C legal — integrar los textos ya entregados** (los abogados los entregaron el 24-jul; los cinco flujos de UI esperan el reemplazo de los provisionales).

**La frase que resume todo**: Rizora tiene un **backend de buena arquitectura con la maquinaria multi-tenant ENCENDIDA y verificada** (24-jul-2026). El diseño estaba; el aislamiento efectivo ahora también, con tests que lo prueban y un control que vigila que no se degrade. Lo que queda antes del beta es una lista corta y concreta — remanentes de A01, cadena de suministro, `frame-ancestors`, alertas, textos legales ya en mano — no una condición estructural.

---

## 4. Cómo se conecta con el flujo de trabajo

**Este documento alimenta dos cosas concretas:**

1. **El backlog de endurecimiento (Gate C).** Las acciones de A01 (RLS real + tests), A02 (backlog ADR-024 + `frame-ancestors`), A03 (lockfile, escaneo, SRI), A09 (alerta mínima) y A10 (gates fail-closed) son la traducción a estándar del trabajo que el Roadmap ya tiene listado para el Gate C, donde viven como **Track de Seguridad** etiquetado `[SEC] [OWASP A0x]`. **Úsalo como checklist de cierre del gate** — pero recuerda: el *cuándo* y el estado de cada ítem los manda el Roadmap; este documento manda el *qué* y el *veredicto*.
2. **El pentest (actividad del cargo de CTO, hoy sin titular).** El orden importa y el ADR lo dice bien: *el pentesting no es lo primero; solo tiene sentido atacar una seguridad ya consolidada*. Este documento es el **mapa de dónde apuntar primero** cuando llegue ese momento: el **pentest (actividad del cargo de CTO)** debería apuntar a A01 (intentar cruzar tenants), A10 (forzar errores para ver si algún gate concede), A07 (manipular la sesión cacheada) y A02 (buscar funciones expuestas y headers ausentes). El resultado del pentest vuelve al ADR y al Gate C vía Agustín.

**Nota de método (DevSecOps sin ceremonia).** Para un equipo de dos, la seguridad **no necesita** un proceso de equipo de 50. El control que más rinde ya está adoptado: **ramas cortas + PR revisado** (separación de funciones, A03). Lo que falta es automatizar lo barato (escaneo de dependencias en CI, tests de aislamiento que corren solos) y **no** montar ceremonia que cueste más de lo que aporta. La regla del proyecto aplica acá también: proceso mínimo viable que cierre el trabajo, sin overhead diseñado para equipos grandes.

---

## 5. Trazabilidad: categoría ↔ ADR ↔ gate

| Categoría 2025 | ADR relevante | Gate | Acción principal pendiente |
|---|---|---|---|
| A01 Broken Access Control | ADR-001, 004, 005, 012, 014 | **B ✅ + C** | ✅ RLS real por org/rol (0 `mvp_`) · ✅ tests de cruce en verde · ✅ borrado blando cerrado (guard server-side) · **quedan: policy `contacts` para externos + verificar snapshots por org** |
| A02 Security Misconfiguration | ADR-024, 011, 026 | **C** | ✅ CSP endurecido **en producción** · ✅ REVOKE TRUNCATE/TRIGGER/REFERENCES (repetirlo en cada CREATE TABLE) · **queda: `frame-ancestors`** |
| A03 Supply Chain Failures | ADR-026 (npm run gate) | **C + horizonte** | **SRI en los CDN, pin exacto de `supabase-js`, quitar la doble carga de `xlsx`**; atar `npm run gate` a CI — sin cambios con el corte |
| A04 Cryptographic Failures | ADR-011 | Mantenimiento | Revisar `md5`→`pgcrypto` según uso |
| A05 Injection | ADR-024, 026 | **C** | ✅ `'unsafe-inline'` fuera de `script-src` **en producción**; **queda: sanear `showToast` (escapeHtml)** |
| A06 Insecure Design | ADR-018, 025 (y todo el ADR) | Mantenimiento | Threat modeling del flujo multi-tenant |
| A07 Authentication Failures | ADR-003 | **B/C** | Google OAuth + no confiar en sesión cacheada |
| A08 Data Integrity Failures | ADR-012, 020, 023, 014, 026 | **C** | ✅ Corte hecho (deploy automatizado por workflow) · ✅ Storage capturado en migración · ✅ test de controles post-deploy · **quedan: SRI + atar gates a CI** |
| A09 Logging **and Alerting** | ADR-012, 014 (staging) | **C + horizonte** | Definir y conectar alertas; rate limiting |
| A10 Mishandling of Exceptional Conditions | ADR-014 (fail-closed), 023, 026 | **B/C** | ✅ `authNivelModulo` fail-closed · ✅ contrato no-NULL en helpers (`COALESCE`, control 5 del test) · **quedan: `.catch` en red async + `unhandledrejection` + centralizar errores** |

---

*Fin del documento. Referencia externa: OWASP Top 10:2025, <https://owasp.org/Top10/2025/>, CC BY 3.0. Este documento es canónico para Rizora y subordinado al PRD (producto) y al ADR de Backend (técnico).*
