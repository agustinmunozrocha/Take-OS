# Corte monolito → modular · Handoff nocturno (2026-07-24)

> **Para Agustín en la mañana:** todo lo REVERSIBLE quedó hecho, probado y commiteado
> en la rama `chore/gateB-rls-endurecimiento`. Lo IRREVERSIBLE (el corte en sí) quedó
> reducido a la checklist de abajo, esperando tu único "sí". Nada tocó la BD de
> producción ni borró el monolito.

---

## 1) Qué se hizo esta noche (todo reversible)

### Gate B · Auditoría de seguridad RLS multi-tenant (solo lectura sobre prod)
- **No queda NINGUNA política `mvp_`**: las 79 tablas de `public` tienen RLS activo con
  políticas `b_*` que pasan por `auth_nivel(módulo, org)` / `auth_ve_proyecto` /
  `auth_codigo_perfil`. Las 3 funciones verifican **membresía activa** y son
  SECURITY DEFINER con `search_path` fijo. El Gate B estaba mucho más avanzado de lo
  que decía el handoff viejo.
- **Storage**: buckets privados con políticas org-scoped (primer segmento del path =
  org del caller; `documentos-legales` exige además el módulo legal;
  `herramientas-personales` por usuario). Estaban creadas a mano → capturadas en
  migración (ver abajo).
- **Hueco P1 CONFIRMADO (y cerrado)**: eliminar/restaurar proyecto es un UPDATE de
  `projects.deleted_at` gateado solo por `info_proyecto='E'` → un **Ejecutivo**
  (info=E, eliminar=none) podía fabricar la request y borrar proyectos. El monolito
  (main:9530) y el modular (kanban.js:378) hacen ese UPDATE directo con chequeo solo
  client-side.
- **Hallazgo nuevo**: `anon` y `authenticated` tenían TRUNCATE/TRIGGER/REFERENCES en
  todas las tablas por el GRANT ALL por defecto — y **TRUNCATE no pasa por RLS**.
  Sin vector activo hoy (PostgREST no expone TRUNCATE), pero se revocó por defensa
  en profundidad.

### Gate B · 3 migraciones de endurecimiento (en la rama; APLICADAS y PROBADAS en staging)
| Archivo | Qué hace |
|---|---|
| `20260724120000_gateB_guard_soft_delete_proyectos.sql` | Trigger BEFORE UPDATE: tocar `deleted_at` exige `eliminar_proyecto='E'` (server-side). Deploy-safe: el flujo real del Admin sigue igual, no requiere cambio de frontend. |
| `20260724121000_gateB_revoke_truncate_trigger_references.sql` | REVOKE TRUNCATE/TRIGGER/REFERENCES a anon y authenticated en todo `public`. |
| `20260724122000_gateB_storage_policies_captura.sql` | Captura reproducible de las 8 políticas de `storage.objects` + 2 helpers (`auth_es_miembro_org_txt`, `auth_nivel_org_txt`). No-op donde ya existen. |

### Pruebas de seguridad ejecutadas en staging (todas ✅)
1. **Bypass cerrado**: `perfil@ejecutivo.com` UPDATE de `deleted_at` → excepción
   `takeos_auth` del guard (y su UPDATE normal sí pasó → el bloqueo es específico).
2. **Flujo legítimo**: `perfil@administrador.com` borra y restaura sin error.
3. **Cruce entre orgs**: admin de **Gondor** ve **0** proyectos/contactos/empresas/
   presupuestos de **Rivendell**, y 4 proyectos propios.
4. **Invitado** (bd=none): 0 contactos, 0 cuentas bancarias visibles.
5. **Revokes efectivos**: 0 grants no-DML restantes para anon/authenticated.
6. Proyecto de prueba PR-RIV-0011 intacto (todo con rollback).

### R4 · Alineación de migraciones (staging ↔ prod)
Estado real verificado por MCP esta noche (no el de las notas viejas):
- **Drift inverso arreglado YA**: prod tenía 3 migraciones del 13-jul que staging no
  tenía. Se aplicaron a staging **con sus versions exactos** (`20260713120000/130000/
  140000`) → historiales comparables.
- **Reparado YA**: `scouting_persistencia_bd` estaba en staging con timestamp
  regenerado (`20260710021048`) → corregido a `20260709120000` (el de prod/main).
- **Set del corte renumerado** (en la rama): las 6 pendientes-de-prod quedaron con
  timestamps limpios y posteriores a todo lo aplicado en prod, listas para viajar en
  el merge sin colisiones (la colisión `20260709120000` presupuesto-vs-scouting quedó
  eliminada):
  `20260724110001_presupuesto_no_rodaje_reordenar_shadow` · `…110002_organization_services`
  · `…110003_renombrar_servicio_rpc` · `…110004_companies_representante_duenos`
  · `…110005_modulo_inventario` (rescatada del repo staging, rama
  `reconciliacion-staging-inventario`) · `…110006_storage_buckets_paridad_staging`
  (no-op en prod: los buckets ya existen).
- El árbol `supabase/migrations/` de la rama quedó **idéntico a main/prod** hasta
  `20260713140000` y agrega solo las 6 del corte + las 3 de Gate B → **el merge a
  main es limpio y el deploy por Branching aplica exactamente 9 migraciones**, todas
  ya probadas en staging (donde los mismos objetos existen y funcionan hace días).

### Prep del flip (verificado)
- `.env.production` → `zplcgetquwxybkrpmcvl` (prod) · `.env.staging` → `jovroab…` ✅
- `npm run build` (modo producción) compila ✅ y el bundle arranca limpio apuntando a
  prod (login renderiza, "arranque modular OK", CSP activa; único 404 = favicon,
  igual que en staging).
- `deploy.yml` (ya en etapa4): en push a `main` del repo de prod hace `npm run build`
  y publica `frontend/dist` en Pages. **Ya distingue repo prod vs staging.**
- Pages HOY: Take-OS = `legacy` (sirve el monolito desde la raíz de main) ·
  takeos-staging = `workflow`. **El flip es cambiar Take-OS a `workflow`.**
- **Rollback trivial**: mientras `index.html` (monolito) siga en la raíz de main,
  volver a `legacy` re-sirve el monolito al instante. Y las 9 migraciones son
  aditivas → el monolito siguió funcionando con ellas en staging todo este tiempo.
  Por eso: **NO borrar el monolito en el mismo commit del corte** (ver fase 3).

---

## 2) CHECKLIST DEL CORTE (lo que apruebas en la mañana — irreversible)

**Pre-vuelo (5 min, yo lo hago contigo):**
- [ ] Revisar y aprobar la rama `chore/gateB-rls-endurecimiento` (diff pequeño:
      3 migraciones nuevas + renombres + este doc).
- [ ] Merge de esa rama → `etapa4-integracion`.

**El corte:**
- [ ] 1. Merge `etapa4-integracion` → `main` + push. Esto dispara DOS cosas:
      Supabase Branching aplica las 9 migraciones a PROD, y el workflow de Pages
      corre (fallará o quedará en espera mientras Pages siga en legacy — esperado).

      **Ensayo de merge ya ejecutado esta noche** (worktree desechable, abortado):
      solo 3 conflictos, con receta:
      - `index.html` (modify/delete): git **conserva la versión de main** → resolver
        con `git add index.html`. **El monolito sobrevive el merge** = rollback intacto.
      - `docs/CHANGELOG.md` (1 conflicto): unión de ambos bloques (los dos son historia).
      - `docs/CLAUDE.md` (6 conflictos): quedarse con la versión de **main** (v0.3, trae
        la regla R4) y anotar al final que el corte se ejecutó — la narrativa
        "producción ≠ staging" queda obsoleta con este merge; el Redactor consolida después.
      Todo lo demás (deploy.yml, frontend/, migraciones, docs nuevos) mergea solo.
- [ ] 2. Cambiar Pages de Take-OS a workflow:
      `gh api -X PUT repos/agustinmunozrocha/Take-OS/pages -f build_type=workflow`
      y relanzar el workflow (pestaña Actions → "Deploy a GitHub Pages" → Run).
- [ ] 3. Verificar PROD: `https://agustinmunozrocha.github.io/Take-OS/` sirve el
      modular (título/console "arranque modular OK"), login real de Agustín, smoke
      de 3-4 módulos (Gastos, Presupuesto, BD, Kanban) y que Fondos por rendir esté.
- [ ] 4. Reparar historial de staging (SQL listo abajo) para que quede espejo de prod.

**Rollback si algo sale mal:** `gh api -X PUT repos/agustinmunozrocha/Take-OS/pages -f build_type=legacy`
(vuelve el monolito al aire; las migraciones aplicadas no estorban al monolito).

**Fase 3 (días después, cuando el modular esté estable en prod):**
- [ ] Borrar `index.html` (monolito) y assets muertos de la raíz de main.
- [ ] Decidir el destino del repo takeos-staging / rama etapa4 (archivar).
- [ ] Gate C (legal) sigue pendiente para el beta — no bloquea este corte.

## 3) SQL post-corte para staging (dejar espejo)
```sql
-- En staging (jovroabtwysliryppthh) DESPUÉS del merge a main:
update supabase_migrations.schema_migrations set version='20260724110001' where name='presupuesto_no_rodaje_reordenar_shadow' and version='20260709134236';
update supabase_migrations.schema_migrations set version='20260724110002' where name='organization_services' and version='20260710165948';
update supabase_migrations.schema_migrations set version='20260724110003' where name='renombrar_servicio_rpc' and version='20260710171621';
update supabase_migrations.schema_migrations set version='20260724110004' where name='companies_representante_duenos' and version='20260710231313';
update supabase_migrations.schema_migrations set version='20260724110005' where name='modulo_inventario' and version='20260711000000';
update supabase_migrations.schema_migrations set version='20260724110006' where name='storage_buckets_paridad_staging' and version='20260714231313';
```

## 4) Notas y deudas registradas (no bloquean el corte)
- **P2 opcional**: archivar contactos/empresas/locaciones también es UPDATE de
  `deleted_at` gateado por `bd='E'` (la UI lo restringe a Admin). Un guard como el de
  projects es posible, pero hay que revisar antes si la fusión de duplicados de BD
  archiva filas como no-admin (podría romperla). Documentado, no aplicado.
- **Regla operativa nueva**: toda migración futura con CREATE TABLE debe cerrar con
  `REVOKE TRUNCATE, TRIGGER, REFERENCES … FROM anon, authenticated` (no hay forma de
  cambiar los default privileges con el rol postgres de Supabase).
- Staging quedó con las 3 migraciones de Gate B aplicadas y probadas; prod las recibe
  en el merge (R4: quedan como pendientes-de-prod hasta el corte — es exactamente el
  plan).
- El deploy a staging del código de esta rama (force-push) queda a tu criterio en la
  mañana; no era necesario para las pruebas (fueron por SQL directo).
