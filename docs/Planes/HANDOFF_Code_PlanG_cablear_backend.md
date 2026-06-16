# Plan G — Cablear el backend ya construido (privacidad · cookies · edad · vista de externos)

**De:** BD Expert
**Para:** **Claude Code** (esto es tu **Plan G**) · y el chat **Dev** como referencia
**Fecha:** 15 de junio de 2026
**Relación con el plan del Dev (Frentes A–F):** este documento **desbloquea** los frentes que esperaban a la base. **A (privacidad)** y **C (cookies)** ya tienen todo su backend construido y probado. Aquí están los contratos exactos para cablearlos, más dos piezas nuevas (edad y lente de externos).

---

## 0 · Para Code: cómo trabajar este plan

Mismo método de siempre: **Plan Mode primero**, descompón en pasos chicos y revisables, **commitea cada paso**, y junto a cada diff explica en simple **qué cambia, en qué función y qué pantalla afecta**. Ningún frente de un viaje.

**Alcance de G:** cablear lo que la base ya entregó → **A** (5 derechos del titular + pantalla de transferir administración), **C** (cookies), **edad** (parte de A/menores) y el **lente de personas para externos** (apoya el Frente F). Los frentes **E, B, F** del plan del Dev son puro frontend y **no dependen de la base** (van por su carril). El frente **D** (límites de plan) **no entra acá**: su backend ya está, pero se diseña primero en el chat Dev y lo aprueba Agustín.

> **Regla de oro de los contratos:** todas estas funciones re-derivan la identidad y los permisos en el servidor. El cliente **envía y refleja**; nunca decide el acceso. Si una función devuelve un error con prefijo `TAKEOS_`, eso es señal para mostrar una UI específica, no un error genérico (ver §6).

---

## 1 · Frente A — Derechos del titular (backend LISTO, a cablear)

### 1.1 Exportar mis datos — `exportar_mis_datos()`
- **Parámetros:** ninguno (usa la sesión).
- **Devuelve (jsonb):** `{ titular, generado_at, formato:"TakeOS export v1", datos:{ perfil, cuentas_bancarias[], membresias[], consentimientos[], actividad_resumen }, integridad_md5 }`.
- **Costura:** `_pdExportSolicitar()`. El cliente dispara, recibe el jsonb y lo ofrece como **descarga** (archivo JSON). El campo `integridad_md5` es una huella para verificar que el archivo no fue alterado.
- **Nota:** una firma criptográfica con llave sería un paso de Edge Function a futuro; hoy va la huella md5, que cumple para portabilidad.

### 1.2 Revocar consentimiento — `revocar_consentimiento(p_consent_id uuid)`
- **Devuelve:** `{ estado:'revocado', organization_id }` o, si ya estaba, `{ estado:'ya_revocado' }`.
- **Errores:** `TAKEOS_UNICO_ADMIN:<org_uuid>` → no puede revocar porque es el único administrador de esa productora; mándalo a **transferir administración** (1.6). También: "consentimiento inexistente", "ese consentimiento no es tuyo".
- **Costura:** `_pdRevocarConfirmar()`. El **listado** ya lo lee el cliente por RLS; esto es solo la escritura. Efecto: marca la revocación (no borra) y deja la membresía **inactiva**.

### 1.3 Eliminar cuenta — `solicitar_eliminacion_cuenta()`
- **Devuelve:** `{ estado:'programada', ejecuta_despues_de:<fecha +30 días> }`.
- **Errores:** `TAKEOS_UNICO_ADMIN:<json con [{organization_id, nombre}]>` → muestra la lista de productoras y manda a transferir antes de poder borrarse.
- **Costura:** `_pdElimConfirmar()`. Programa la anonimización a **30 días** (es **automática**, ya corre sola). La cuenta **sigue funcionando** durante la gracia; el corte y la anonimización ocurren juntos al vencer el plazo.

### 1.4 Cancelar eliminación — `cancelar_eliminacion_cuenta()`
- **Devuelve:** `{ estado:'cancelada' }`.
- **Errores:** "no hay eliminacion pendiente", "el plazo de recuperacion ya vencio".
- **Costura:** `_pdElimCancelar()`. Solo funciona dentro de los 30 días.

### 1.5 Pre-chequeo de único admin — `mis_organizaciones_como_unico_admin()`
- **Devuelve:** filas `(organization_id, nombre)` de las productoras donde el usuario actual es el **único** administrador.
- **Uso:** en `_pdElimCargar()`, llama esto **antes** de mostrar el botón de borrar. Si devuelve filas, muestra de entrada "para eliminar tu cuenta, primero transfiere la administración de: X, Y", en vez de dejar que choque con el error. Mejor UX que adivinar.

### 1.6 Transferir administración — `transferir_administracion(p_org_id uuid, p_target_user_id uuid)` *(pantalla NUEVA)*
- **Devuelve:** `{ estado:'ok', nuevo_admin }`.
- **Errores:** "solo un Administrador puede transferir", "la persona no es miembro activo", "el Administrador debe ser un miembro interno".
- **Uso:** es la **pantalla nueva** del plan del Dev (parte de A, adelantable). Asciende a otro miembro **interno activo** a Administrador; con eso deja de ser único admin y se desbloquea revocar/eliminar.
- **Candidatos a listar:** miembros **internos activos** de la organización. Si el cliente ya los lista en el Control Room (gestión de miembros), reúsa esa lista. Si no tienes de dónde sacarla limpia, avísame y armo un lente de "miembros internos de la org".

---

## 2 · Frente C — Cookies (backend LISTO, a cablear)

### 2.1 Guardar — `guardar_consentimiento_cookies(p_analitica boolean, p_marketing boolean, p_version text)`
- **Devuelve:** `uuid` del registro.
- **Costura:** `_pdCookiesGuardar()`. Es **append-only**: cada decisión es una fila nueva (queda historial versionado).

### 2.2 Derivar "ya decidió" — leer la tabla `cookie_consents`
- El cliente lee `cookie_consents` (RLS: solo sus propias filas), la más reciente por `accepted_at`.
- **Costura:** `_pdCookieBannerDecidir()`. "Ya decidió" = existe una fila con la **`version` vigente**. Si la versión sube (cambian las políticas), el banner vuelve a aparecer.
- **Abierto (decisión de producto):** el caso del visitante **anónimo** (antes de loguearse) no tiene fila en servidor. El cliente puede sostener la decisión localmente y persistirla al loguear. Si quieres cubrir ese caso formalmente, lo conversamos con Agustín.

---

## 3 · Edad — verificación obligatoria (backend LISTO)

- **Cómo funciona:** la fecha de nacimiento se trata **igual que los datos de pago** — opcional al registrarse, **obligatoria para participar**. Se sumó al gate canónico de requisitos.
- **Al aceptar una invitación** (`consentir_invitacion`): si falta la fecha, devuelve `TAKEOS_REQUISITOS:edad` (junto con `perfil`/`banca` si también faltan). El cliente ya maneja ese mecanismo; solo debe **mapear `edad` → "completa tu fecha de nacimiento"**.
- **Al crear productora** (`provisionar_organizacion`): si falta la fecha → `TAKEOS_REQUISITOS:edad`; si es **menor de edad** → `TAKEOS_MENOR_EDAD`.
- **Qué debe hacer Code:**
  1. Capturar `fecha_nacimiento` en el **formulario de perfil** (el campo ya existe en `user_profiles`).
  2. Que sea opcional al crear la cuenta pero **obligatorio para participar/crear** (como pago).
  3. Mapear `TAKEOS_REQUISITOS:edad` y `TAKEOS_MENOR_EDAD` a mensajes claros.
- **Comportamiento a tener presente:** hoy la fecha se exige al aceptar **cualquier** invitación (no solo las ligadas a un proyecto). Si Agustín prefiere acotarlo solo a invitaciones con proyecto, se ajusta en la base; avísame.

---

## 4 · Lente de personas para externos (backend LISTO) — apoya el Frente F

### `personas_de_mis_proyectos()`
- **Devuelve:** filas `(project_id, proyecto, nombre, cargo, email, telefono)`.
- **Qué entrega:** de los proyectos que el usuario **ve** (interno: toda su organización; externo: solo los proyectos donde tiene cargo activo), las personas con **solo esos cuatro datos visibles** (nombre, cargo, correo, celular). **No** expone RUT, dirección, fecha de nacimiento ni nada más.
- **Qué debe hacer Code:** cuando un **externo** necesite ver a las personas de su proyecto, debe leer por **esta función**, no por la tabla `contacts` (a la que el externo no tiene —ni debe tener— acceso directo). Esto hace efectivo el modelo "el externo ve solo lo de sus proyectos".
- **Alcance:** por ahora cubre **personas**. Empresas y locaciones para externos **no** están incluidas (decisión de producto). Si un externo necesitara, por ejemplo, la dirección de una locación de su rodaje, es otra pieza; se pide aparte.
- **Pendiente legal (contexto, no es tu tarea):** esta visibilidad del celular del usuario hacia externos está yendo a Legal para una glosa en los T&C.

---

## 5 · Frente D — Límites de plan (backend LISTO, **pero no entra en G**)

El backend ya impone los topes y devuelve los códigos. **No lo implementes desde acá:** este frente se **diseña primero en el chat Dev** (copy chileno, tono Primate, CTA, momento), Agustín lo aprueba, y recién ahí te llega. Ver el handoff dedicado de límites de plan. Códigos involucrados en §6.

---

## 6 · Catálogo de errores tipados (mapéalos a UI, no los muestres crudos)

| Código que devuelve la base | Qué pasó | UI sugerida |
|---|---|---|
| `TAKEOS_UNICO_ADMIN:<org / json>` | Es el único admin de una o más productoras | Mandar a **transferir administración** (1.6); mostrar la(s) productora(s) |
| `TAKEOS_REQUISITOS:<lista>` | Faltan requisitos del perfil (`perfil`, `edad`, `banca`) | Mandar a completar esos campos; partir la lista por coma |
| `TAKEOS_MENOR_EDAD` | Usuario menor de edad intentó crear productora | Bloquear con mensaje claro de edad mínima |
| `TAKEOS_PLAN_LIMITE:proyectos:<máx>` | Tope de proyectos del plan | **Momento de venta** (Frente D) |
| `TAKEOS_PLAN_LIMITE:colaboradores:<máx>` | Tope de colaboradores del plan | **Momento de venta** (Frente D) |
| `TAKEOS_PLAN:finanzas` | Módulo no incluido en el plan | **Momento de venta** (Frente D) |
| `TAKEOS_PLAN:reporte_cierre` · `TAKEOS_PLAN:notificaciones` | Reservados; aún no se disparan | Dejar el manejo preparado |

Patrón general: si el texto del error empieza con `TAKEOS_`, parte por el prefijo y arma la UI correspondiente. El número o lista después de los dos puntos viene listo para usar (no escribas topes a mano).

---

## 7 · Decisiones de producto **cerradas** (no las reinterpretes)

- **Eliminar cuenta = anonimizar** (no borrado físico) + **30 días** recuperables; el acceso **sigue** durante la gracia.
- La anonimización alcanza la ficha del titular en **todas** las productoras donde aparezca (por RUT o correo). Consentimientos y auditoría se **conservan** como evidencia.
- **Externos** ven solo **nombre/cargo/correo/celular** de personas de **sus** proyectos. Nada más, y nada de empresas/locaciones por ahora.
- **Edad** obligatoria para participar y para crear productora; **menores no** crean productoras.

## 8 · Abiertas (esperan a Agustín; no asumas)

- Caso de cookies del **visitante anónimo** pre-login.
- Si la **edad** se exige en toda invitación o solo en las ligadas a proyecto (hoy: toda invitación).
- Empresas/locaciones para externos (hoy: no).

---

## 9 · Orden sugerido para G (alineado con el plan del Dev)

1. **Pantalla de transferir administración** (1.6) — es UI nueva y desbloquea el resto de A; el Dev ya la marcó como adelantable.
2. **Cablear los 5 derechos** (1.1–1.5) — ahora que la base está, conéctalos y verifícalos punta a punta.
3. **Cookies** (§2) — cablear guardar + derivar "ya decidió".
4. **Edad** (§3) — campo en el perfil + mapeo de errores.
5. **Lente de externos** (§4) — usar `personas_de_mis_proyectos()` donde corresponda (se cruza con el Frente F).

> Recuerda: **E** (permiso fail-closed), **B** (bug de refresco) y **F** (cartel de externo) son puro frontend del plan del Dev, sin dependencia de la base; pueden ir en paralelo. **D** espera diseño.

---

*Cada función de §1–§4 ya está construida y probada en la base (pruebas en transacción revertida). Si algo devuelve un error que no calza con este contrato, avísame antes de envolverlo. — BD Expert*
