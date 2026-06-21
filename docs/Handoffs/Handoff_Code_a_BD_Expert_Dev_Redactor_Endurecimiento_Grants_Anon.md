# Handoff · Code → BD Expert · Dev · Redactor — Endurecimiento de grants `anon` + rebuild de staging

**De:** Code (sesión con Agustín, 2026-06-21)
**Para:** **BD Expert** · **Dev (Code)** · **Redactor** (cada uno tiene su sección abajo)
**Estado:** ✅ **Resuelto y desplegado a producción** (merge de PR #3). Staging reconstruida y fiel a prod.
**Lee primero:** ADR-023 (flujo BD en código) · ADR-024 (endurecimiento de ejecución) · este handoff.

---

## 0. TL;DR (una línea)
Reconstruyendo la branch `staging` fiel a producción, se detectó que **las migraciones no reproducían los REVOKE de `anon`** de prod: un rebuild desde cero dejaba **42** funciones anon-ejecutables vs **23** en producción. Se cerró con una migración nueva (`20260621120000_revoke_anon_funciones_sensibles`, ya en prod, **no-op allí**) y se corrigió el mismo patrón en la migración de concurrencia (Pasada 1) **antes** de su despliegue.

---

## 1. Qué se hizo (cronología)
1. **Rebuild de staging** (handoff previo Code→Code): la branch `staging` (`jovroabtwysliryppthh`) estaba driftada (orphan `20260617161042`, 42 anon-exec) y vacía. Se reconstruyó **por CLI** (`supabase db reset --linked` contra la branch — **nunca** prod, target verificado) desde las migraciones canónicas, y se repobló (catálogos → Tier B → Tier A).
2. **Hallazgo:** tras el reset limpio, anon-ejecutables seguía en **42, no 23**. El supuesto del handoff ("reset limpio → 23") era incorrecto.
3. **Causa raíz** identificada y probada (ver §2).
4. **Fix (b):** migración `20260621120000_revoke_anon_funciones_sensibles` — revoca `anon` (y `PUBLIC`) en las 19 funciones faltantes. Validada en staging (reset → 23, set idéntico a prod) y **mergeada a producción** (PR #3). En prod es **no-op** (ya estaban revocadas; solo sincroniza el código con la base).
5. **Fix (a):** corregido el bloque de permisos de la migración de concurrencia Pasada 1 (`guardar_proyecto`): `FROM PUBLIC` → `FROM PUBLIC, anon`. **No desplegada aún**; queda lista y segura para cuando se ejecute esa tarea.

---

## 2. Causa raíz (técnica)
- La migración base `…150834_remote_schema` (dump de prod) captura las funciones sensibles con `REVOKE ALL … FROM PUBLIC; GRANT … TO authenticated;` — **sin** revocar a `anon`.
- Supabase tiene **DEFAULT PRIVILEGES** que otorgan `EXECUTE` a `anon` (y `authenticated`, `service_role`) **explícitamente** a cada función nueva en `public`. Verificado en prod (`pg_default_acl` → `anon=X/supabase_admin`).
- Por eso `REVOKE … FROM PUBLIC` **no alcanza**: `anon` conserva su grant **explícito** (que no proviene de PUBLIC). En una BD fresca (reset de staging, preview branch de un PR, recuperación ante desastre) esas funciones quedan anon-ejecutables.
- En **producción** las 19 ya estaban revocadas de `anon` (de ahí el 23), pero **ese estado no estaba capturado en las migraciones** — era estado vivo de prod no reproducible. Hueco de "BD en código".
- La `…144834_endurecimiento` ya usaba el patrón correcto (`REVOKE … FROM PUBLIC, anon`) pero **solo cubría 7** funciones de escritura.

**Evidencia** (probada en la branch, transacción revertida, sin persistir): `CREATE` función → `anon` puede = **true**; tras `REVOKE FROM PUBLIC` → **true**; tras `REVOKE FROM PUBLIC, anon` → **false**.

---

## 3. Para **BD Expert**
- **Regla de patrón (a canonizar):** toda migración que **crea o recrea** una función sensible en `public` (incluido cualquier `DROP+CREATE`) debe revocar explícitamente a `anon`:
  ```sql
  REVOKE ALL ON FUNCTION public.<fn>(<args>) FROM PUBLIC, anon;
  GRANT EXECUTE ON FUNCTION public.<fn>(<args>) TO authenticated;  -- si corresponde
  ```
  `FROM PUBLIC` solo **no basta** por el default-priv de Supabase.
- **Afecta la migración de concurrencia:** Pasada 1 ya corregida (a). **Pasada 3** (`guardar_operaciones_4*`, que hará `DROP+CREATE`) **debe** usar `, anon`. Pasada 2 también, si recrea funciones.
- **Las 19 que cubre (b):** `asignar_cargo_a_miembro`, `cancelar_eliminacion_cuenta`, `exportar_herramienta`, `exportar_mis_datos`, `guardar_cargos`, `guardar_consentimiento_cookies`, `guardar_pagos_cliente`, `invitaciones_de_organizacion`, `marcar_notificaciones_leidas`, `mis_organizaciones_como_unico_admin`, `personas_de_mis_proyectos`, `procesar_eliminaciones_vencidas`, `resolver_rebind`, `revocar_consentimiento`, `rpc_assert_cupo_colaborador`, `rpc_assert_cupo_proyecto`, `rpc_assert_plan`, `solicitar_eliminacion_cuenta`, `transferir_administracion`.
- **Recomendación más sistémica (a evaluar, NO implementada):** un `ALTER DEFAULT PRIVILEGES … REVOKE EXECUTE ON FUNCTIONS FROM anon` para el rol que crea funciones, de modo que las funciones nuevas **no nazcan** anon-ejecutables (deny-by-default real) y solo se haga `GRANT … TO anon` donde de verdad se quiera (flujos de invitación, etc.). Requiere auditar que las funciones que SÍ deben ser anon tengan su GRANT explícito. Es decisión de arquitectura de seguridad.

---

## 4. Para **Dev (Code)**
- **Staging está lista** para el trabajo de concurrencia: branch fiel a prod (**8 migraciones**, anon=23, 77 tablas / 147 policies / 71 funcs / 31 triggers) y repoblada (3 orgs, ~300 contactos, 3 usuarios). **Login de prueba: `12345678`** (usuarios `agustinmr21@gmail.com`, `jidelacuadra@gmail.com`, `denethor@gondor.test`).
- **La migración de concurrencia (Pasada 1) ya está corregida** (`, anon` en `guardar_proyecto`): al desplegarla (RPC + cliente **juntos**, como dice su handoff), **no reabrirá** el hueco. Archivo corregido en `Downloads/files 2/20260621170000_guardar_proyecto_concurrencia_p1_header_budget.sql`.
- **Secuencia intacta** (reset → Tier B → Tier A → migración de concurrencia). Ahora (b) está en la cadena de migraciones, así que **cada reset deja staging fiel** (anon=23) sin intervención manual.
- Sin cambios al resto del handoff de concurrencia (read-path: traer `projects.version`, `budget_line_items.client_uuid`/`version` en la carga — sigue siendo tu pendiente).

---

## 5. Para **Redactor** (qué consolidar en los canónicos)
- **Cifras:** ahora **8 migraciones** (era 7). Actualizar: **ADR-023** (tabla de migraciones → agregar `20260621120000_revoke_anon_funciones_sensibles`), **Arquitectura §2.2/§7** y su pie, **Roadmap** (cifras), y **CLAUDE.md §8** (dice "Base: 7 migraciones").
- **ADR-024 (endurecimiento):** registrar que el endurecimiento de `anon` quedó **completo**: `…144834` cubrió 7 RPC de escritura; `…120000` cubre las **19 sensibles restantes**. Documentar el **patrón canónico** `REVOKE … FROM PUBLIC, anon` y la **causa** (default-priv de Supabase otorga anon explícito; el dump no captura la ausencia de ese grant).
- **Aprendizaje de flujo** (consolida el §6 del handoff de rebuild): "reset reconstruye fiel" asume **CLI** *y* que las migraciones capturen los grants — el dump **no** capturaba los REVOKE de `anon`, por eso hubo que cerrarlo con migración. La branch `staging` **sigue sin ligar a Git**; con (b) en la cadena un rebuild fresco ya da 23, pero la recomendación de ligarla a Git queda como mejora de horizonte.
- **No reabrir:** el fix (a) es **pre-despliegue** de la concurrencia (corrección de un archivo), **no** un cambio aplicado a prod.

---

## 6. Estado verificado (2026-06-21)
- **Producción** (`zplcgetquwxybkrpmcvl`): 8 migraciones (incl. `20260621120000`), **anon-exec = 23**, 77 tablas. Datos **intactos** (la migración es no-op de grants). `guardar_pagos_cliente` anon = false.
- **Staging** (`jovroabtwysliryppthh`): 8 migraciones (sin orphan), **anon-exec = 23** (por migración), estructura = prod, repoblada (tax_rates 12, orgs 3, contacts 300, auth 3).
- **Git:** PR #3 mergeado a `main`; canónicos (`d35f84f`) pusheados; migración (b) commiteada en ambos repos (`Take-OS` y `takeos-staging`).

---

*Handoff Code → BD Expert · Dev · Redactor. Producción intacta (deploy = no-op de grants). El arbitraje, si hace falta, es de Agustín.*
