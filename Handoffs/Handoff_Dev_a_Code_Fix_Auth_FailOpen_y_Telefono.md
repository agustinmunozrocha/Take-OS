# Handoff — Dev → Claude Code
## Tres tareas: (1) fail-open de autenticación · (2) normalización del teléfono · (3) Frente D — límites de plan

**De:** Dev (chat asesor / frontend)
**Para:** Claude Code, vía Agustín
**Fecha:** 15 de junio de 2026
**Archivo:** `index.html` (V11.14.0)
**Método:** Plan Mode primero, descompón en pasos chicos y revisables, commitea cada paso, y junto a cada diff explica en simple qué cambia, en qué función, y qué pantalla/flujo afecta. **Orden sugerido:** Fix 1 (seguridad) primero, luego Fix 2, y el **Frente D** al final —es una *feature*, no un fix: descomponla en más pasos. Las tres tareas son independientes.

---

## Fix 1 — Una cuenta borrada/ inválida no debe poder entrar (fail-open de auth)

**Qué pasa hoy:** si en el navegador quedó una sesión guardada pero la cuenta ya no existe en el servidor (se borró `auth.users`), la app igual entra y deja al usuario en el **Panel Personal** vacío, en vez de mandarlo al **login**.

**Por qué:** el portero `cloudGate` confía en `getSession()` (que lee la sesión **local**, sin preguntarle al servidor si la cuenta sigue viva). Pasa el chequeo de mismo-usuario + tiempo vigente (`okTTL`) y llama a `onUnlock()`. Más abajo, cuando `getUser()` (que **sí** consulta al servidor) no devuelve usuario, `resolverEspacioYArrancar` cae a `_renderEspacioSeguro` (Panel Personal) en vez de pedir login.

**Dónde:**
- `cloudGate` (~línea 23503) — la rama de sesión restaurada, donde hoy hace `onUnlock()` tras `okTTL`.
- `resolverEspacioYArrancar` (~línea 23690) — el fallback de "sin uid".
- (referencia) `iniciarSesionTakeOS` (~línea 25043) — corre después de `onUnlock`.

**Cambios:**
1. En `cloudGate`, **después** de que la sesión guardada pasa el chequeo `okTTL` y **antes** de `onUnlock()`, validar contra el servidor con `getUser()`. Si devuelve error o ningún usuario → la cuenta ya no existe → `signOut({ scope: 'local' })`, limpiar los sellos `takeos_auth_at` y `takeos_auth_uid`, y caer al **login** (el overlay que ya existe). No llamar `onUnlock()`.
2. Como segunda barrera, en `resolverEspacioYArrancar`, el caso **sin `uid`** (identidad inválida) debe mandar a **login** (signOut + login), no a `_renderEspacioSeguro`.

**Qué NO tocar (crítico):**
- El camino del **usuario válido sin productora** (uid válido + 0 membresías) **debe seguir mostrando el Panel Personal**. Eso es correcto por diseño; no lo conviertas en login.
- La rama **usuario válido sin perfil** → **onboarding** (ya existe en `iniciarSesionTakeOS`); no la toques.
- El cambio aplica solo a **identidad inválida** (sin `uid` / `getUser` falla), que es distinto de "no tiene empresa".

**Criterio de éxito:**
- Con la sesión guardada de una cuenta cuyo `auth.users` fue borrado → entrar a la app lleva al **login**.
- Un usuario válido **sin productora** sigue viendo el **Panel Personal**.
- Un usuario válido **sin perfil** va a **onboarding**.

---

## Fix 2 — Normalizar el teléfono (parsing inconsistente)

**Qué pasa hoy:** el formulario de perfil guarda el teléfono **en crudo**: en `_perfilGuardar` el objeto `prof` arma `telefono: g('pf_telefono')` sin normalizar. Existe un formateador chileno (~línea 8225, deja `+56 9 XXXX XXXX`) pero **solo se usa para mostrar**, no al guardar. Resultado: la columna `user_profiles.telefono` quedó con formatos mezclados.

**Dónde:**
- `_perfilGuardar` (~línea 24987), el objeto `prof`, campo `telefono`.
- Formateador a reutilizar: ~línea 8225.
- Mismos puntos de guardado en **contactos** y **crew** (para consistencia en todo el sistema).

**Cambios (frontend):**
1. Antes del `upsert`, pasar `prof.telefono` por una normalización canónica que reutilice el formateador (~línea 8225).
2. Canónico para **móviles chilenos**: `+56 9 XXXX XXXX`.
3. **No forzar** los que no calzan ese patrón (extranjeros con el toggle "no soy chileno/a", fijos, formatos raros) → guardar los dígitos tal cual, **sin romperlos**.
4. Aplicar la misma normalización en el guardado de teléfonos de contactos y crew.

**Qué NO tocar (crítico):**
- No hacer mangling de números que no son móviles chilenos. Respetar el toggle "no soy chileno/a".

**Datos ya guardados** — primero MIRAR, después corregir (es data de personas; corrección permitida, pero revisa el `select` antes del `update`):

```sql
-- 1) Inspección: ver qué hay y qué se va a normalizar
select telefono,
       regexp_replace(telefono,'\D','','g')           as digitos,
       length(regexp_replace(telefono,'\D','','g'))   as n
from user_profiles
where coalesce(btrim(telefono),'') <> ''
order by n, telefono;
```

```sql
-- 2) Normalización CONSERVADORA: solo móviles chilenos; el resto queda intacto
update user_profiles u
set telefono = '+56 9 ' || substr(nat,2,4) || ' ' || substr(nat,6,4)
from (
  select user_id,
    case when length(d)=11 and left(d,3)='569' then substr(d,3)
         when length(d)=9  and left(d,1)='9'   then d
         else null end as nat
  from (select user_id, regexp_replace(telefono,'\D','','g') as d
        from user_profiles where coalesce(btrim(telefono),'') <> '') z
) y
where u.user_id = y.user_id and y.nat is not null;
```

**Criterio de éxito:**
- Guardar el perfil deja el teléfono en formato consistente.
- Los registros existentes de móviles chilenos quedan en `+56 9 XXXX XXXX`.
- Los teléfonos extranjeros / fijos quedan intactos, sin romperse.

---

## Frente D — Límites de plan como momento de venta (diseño aprobado)

**Qué pasa hoy:** la base ya impone los topes de cada plan y, cuando alguien se pasa, **bloquea la acción y devuelve un código de error** (`TAKEOS_PLAN_LIMITE:…` / `TAKEOS_PLAN:…`). El frontend todavía no los atrapa, así que el usuario ve un error crudo o nada.

**Objetivo:** convertir cada tope en una **invitación sobria a cambiar de plan**, nunca un portazo. El bloqueo duro ya lo garantiza la base; esto es solo la cara.

**Decisiones de producto (cerradas por Agustín — no las reinterpretes):**
- Tono **sobrio y al hueso**: sin signos de exclamación, sin venta agresiva. El hecho + la salida + el CTA.
- El CTA "Ver planes" lleva **al selector de planes de la landing** (el de la página pública; **no** se construye una pantalla de planes aparte).
- *El frontend se diseña para SaaS operativo; el beta no condiciona nada acá.*
- Finanzas se muestra como **módulo bloqueado** (estado vacío con gancho), no como modal.

### D.1 · Mecanismo central (esto primero)
Un solo manejador —p. ej. `manejarErrorPlan(err)`— que, dado un error de la base:
1. Detecta si el mensaje **empieza con** `TAKEOS_PLAN_LIMITE` o `TAKEOS_PLAN`.
2. **Parte el texto por `:`** → familia, recurso y (si viene) tope. Ej.: `TAKEOS_PLAN_LIMITE:colaboradores:4` → recurso `colaboradores`, tope `4`. `TAKEOS_PLAN:finanzas` → recurso `finanzas`, sin tope.
3. Según el recurso, muestra la pieza correspondiente, **usando el tope que viene en el error** (nunca escribas los números a mano).

Los puntos donde se llama a la base (crear proyecto, invitar colaborador, entrar a Finanzas) llaman a este manejador en su `catch`.

### D.2 · Las piezas (copys finales, tono sobrio)

**Proyectos** — `TAKEOS_PLAN_LIMITE:proyectos:<máx>`. Un proyecto cerrado libera cupo → dar las dos salidas.
- *Formato:* modal al chocar.
- *Copy:* "Tu plan permite {máx} proyecto(s) activo(s). Cierra un proyecto para liberar el cupo, o cambia de plan para tenerlos ilimitados."
- *CTA:* **Ver planes** (→ selector de la landing).

**Colaboradores** — `TAKEOS_PLAN_LIMITE:colaboradores:<máx>`. El cupo cuenta activos + invitaciones pendientes.
- *Formato:* modal al invitar de más.
- *Copy:* "Tu plan permite hasta {máx} colaboradores, contando las invitaciones pendientes. Para sumar más, cambia de plan."
- *CTA:* **Ver planes**.

**Finanzas** — `TAKEOS_PLAN:finanzas`.
- *Formato:* pantalla de módulo bloqueado (estado vacío con gancho).
- *Copy:* "Finanzas está disponible en el plan Producción. Te permite registrar cobranzas a clientes, llevar el flujo de caja y la facturación."
- *CTA:* **Ver planes**.

**Reservados** — `TAKEOS_PLAN:reporte_cierre`, `TAKEOS_PLAN:notificaciones`. Aún no se disparan. Deja el manejador con una **plantilla genérica** lista: "{Función} está disponible en el plan Producción." + **Ver planes**. Así, cuando esas funciones existan, no hay que rehacer nada.

### D.3 · Momentos
- **Reactivo** (núcleo, **desbloqueado**): al chocar, el manejador de D.1 muestra la pieza. No depende de nadie — el tope viene en el error.
- **Preventivo** (deseable): avisar **antes** de chocar. Ej. junto a "Nuevo proyecto" cuando queda el último cupo: "Te queda 1 proyecto activo en tu plan." Igual para el último cupo de colaborador.
  - *Dependencia:* el preventivo necesita el **tope del plan y el conteo actual** en el cliente. Si ya están disponibles, hazlo; si no, **avísale a Agustín** y consigo del BD Expert una lectura liviana de "mi plan y mis topes". El reactivo no espera a esto.

**Qué NO hacer:**
- Nada de "No puedes…" / "Función no disponible". Siempre el hecho + la salida + el CTA.
- No escribir los topes a mano: usar el `<máx>` del error.
- No construir una pantalla de planes nueva: el CTA va al selector de la landing.

**Criterio de éxito:**
- Chocar cualquier tope abre la pieza sobria con CTA "Ver planes", nunca un error crudo ni un "no puedes".
- Los números mostrados salen del error (cambiar un tope en la base no obliga a tocar el frontend).
- Los dos códigos reservados ya tienen su plantilla lista.

---

*Orden: Fix 1 (seguridad) → Fix 2 → Frente D (feature, descomponer en pasos). El SQL de la Fix 2: corre el `select` antes del `update`. — Dev*
