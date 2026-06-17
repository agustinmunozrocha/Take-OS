# Handoff — Code → Dev
## Diferencias entre `main` y `llegar-al-beta` (16-jun-2026)

**De:** Code (implementador frontend)
**Para:** Dev (asesor / decisiones de diseño), vía Agustín
**Objetivo:** que el Dev (con Agustín) decida **qué hacer con la rama `llegar-al-beta`**, sabiendo exactamente en qué se diferencia de `main`. Code **no toma** la decisión de diseño; aquí solo deja los hechos verificados y las opciones.

> Nomenclatura: "rama" (branch) = una línea de trabajo paralela en git. "commit" = un cambio guardado con su mensaje. "ancestro común" (merge-base) = el último punto donde dos ramas eran idénticas antes de separarse. "tip" = la punta (último commit) de una rama.

---

## 0. Titular (lo más importante, en peras y manzanas)

**`llegar-al-beta` NO está adelante de `main`: está atrás.**

`llegar-al-beta` apunta **exactamente** al commit `4063756`, que es el **ancestro común** de las dos ramas, y **no tiene ningún commit propio**. `main` es esa misma rama **+ 7 commits** posteriores.

Traducido: `llegar-al-beta` es una **foto vieja de `main`**. No hay trabajo "hacia el beta" viviendo en esa rama que `main` no tenga ya. Al revés: a `llegar-al-beta` le **faltan** cosas que ya están en `main` (la seguridad CSP, dos migraciones de base de datos y la entrada de CHANGELOG).

Números que lo confirman (cualquiera los reproduce, ver §5):
- commits solo en `llegar-al-beta`: **0**
- commits solo en `main`: **7**
- SHA de `llegar-al-beta` (`40637565…`) = SHA del ancestro común (`40637565…`) → son el mismo punto.

---

## 1. Qué le FALTA a `llegar-al-beta` (los 7 commits que solo tiene `main`)

Todos del 16-jun-2026, en orden cronológico (el más antiguo abajo):

| Commit | Tema | Qué aporta |
|---|---|---|
| `885d64a` | Backend / BD | Revoca `EXECUTE` de funciones internas y de trigger a `anon`/`authenticated` (endurecimiento de permisos en la base). |
| `fe59b04` | Backend / BD | Provisión autocontenida: catálogos globales de *defaults*; `seed_permisos` y `provisionar_organizacion` leen del catálogo (sin plantilla Primate). |
| `74b7757` | Seguridad frontend | **CSP** acotada vía `<meta>` (§6 ítem 5) en `frontend/index.html` — la protección del navegador recién aprobada. |
| `06d0251` | Docs | Entrada de CHANGELOG de la seguridad basal §6. |
| `3007553` | Housekeeping | Agregó `frontend/index.staging.html`… |
| `7b34d89` | Housekeeping | …y después lo eliminó. **Estos dos se cancelan**: en el neto ese archivo no existe en ninguna de las dos ramas. |
| `aec0c93` | Housekeeping | Eliminó el handoff de auth de `main` (ver §3). |

---

## 2. Diferencias concretas de archivos (`main` ↔ `llegar-al-beta`)

### Solo en `main` (le faltan a `llegar-al-beta`)
- `frontend/index.html` — el bloque **CSP** `<meta>` (~31 líneas: comentario explicativo + 1 línea `<meta http-equiv="Content-Security-Policy">`). Es el endurecimiento del §6 ítem 5.
- `docs/CHANGELOG.md` — la entrada de **seguridad basal §6** (~32 líneas).
- `supabase/migrations/20260616170000_seed_permisos_autocontenido.sql` — migración **nueva** (180 líneas).
- `supabase/migrations/20260616160154_revoke_funciones_internas.sql` — migración **nueva** (18 líneas).

### Solo en `llegar-al-beta` (no está en `main`)
- `docs/Handoffs/Handoff_Dev_a_Code_Fix_Auth_FailOpen_y_Telefono.md` (147 líneas) — el handoff **Dev → Code** con tres tareas: **(1)** fail-open de autenticación, **(2)** normalización de teléfono, **(3)** Frente D (límites de plan). En `main` este archivo **se borró** (commit `aec0c93`). **No es trabajo nuevo del beta:** es un archivo que quedó atrás porque la rama nunca avanzó.

> En resumen, todas las "diferencias" se explican por una sola causa: `main` siguió avanzando y `llegar-al-beta` se quedó congelada en el punto de partida.

---

## 3. ⚠️ Punto de atención antes de borrar nada

Si se decide **eliminar** `llegar-al-beta`, hay que saber que **esa rama es la última copia en git** del handoff de auth (`Handoff_Dev_a_Code_Fix_Auth_FailOpen_y_Telefono.md`). Sus tres tareas **siguen apareciendo como pendientes** en `CLAUDE.md` §8:

- `authNivel()` *fail-open* → debe retornar `'none'` (fail-closed), no `'E'`.
- Normalización del teléfono.
- (Frente D — límites de plan, es *feature*, no fix.)

**Recomendación de Code:** antes de descartar la rama, confirmar que esas tres tareas ya están **capturadas en un canónico** (Roadmap / ADR) o resueltas. Si ya están registradas en otra parte, el handoff es desechable (es efímero, como todos). Si no, conviene rescatar su contenido primero. **Esta verificación es del Dev/Agustín, no de Code.**

---

## 4. Decisiones de diseño para el Dev (Code NO las toma)

El hecho de fondo: la rama se llama `llegar-al-beta`, pero el trabajo reciente (seguridad + BD) entró **directo a `main`** (vía la rama `seguridad-csp`, ya fusionada). Así que la pregunta de diseño es **qué rol cumple cada rama de aquí en adelante**. Opciones que Code ve, para que el Dev elija:

1. **Borrar `llegar-al-beta`.** Como `main` ya contiene todo lo que ella tiene (menos el handoff borrado a propósito), la rama es **redundante**. Es lo más limpio **si no se le va a dar un rol**. (Antes, hacer la verificación de §3.)
2. **Refrescarla a `main` y convertirla en la línea activa del beta.** Si la intención original era que `llegar-al-beta` fuera la rama de integración hacia el beta, se la pone al día con `main` (fast-forward) y de ahí en adelante el trabajo del beta se construye **sobre ella**, fusionando a `main` al cerrar. Esto sí calza con la doctrina de `CLAUDE.md` §6 ("features grandes → rama dedicada, no directo en `main`").
3. **Investigar primero.** Si el Dev esperaba encontrar trabajo del beta en esa rama y no está, vale la pena confirmar **dónde quedó** ese trabajo (lo más probable: se hizo directo en `main`) antes de decidir 1 o 2.

Code recomienda **no** dejar la rama como está (foto vieja sin rol): o se le da el rol de (2) o se borra en (1); una rama "fantasma" detrás de `main` solo confunde.

---

## 5. Cómo reproducir / verificar (read-only)

```bash
# ¿Tiene llegar-al-beta algún commit propio?  (debe dar 0)
git rev-list --count main..llegar-al-beta

# ¿Cuántos commits tiene main que ella no?     (da 7)
git rev-list --count llegar-al-beta..main

# ¿Es llegar-al-beta el mismo punto que el ancestro común?  (los dos SHA coinciden)
git rev-parse llegar-al-beta
git merge-base main llegar-al-beta

# Qué commits le faltan, con fecha
git log --format='%h  %ad  %s' --date=short llegar-al-beta..main

# Qué archivos difieren y cómo (A=agregado / D=borrado / M=modificado, dirección main->llegar-al-beta)
git diff --name-status main..llegar-al-beta
```

---

*Handoff generado por Code el 16-jun-2026. Es efímero: una vez que el Dev lo use para decidir, se bota (no se acumula ni se commitea). Si algún SHA o ruta no calza al momento de leer, reproducir los comandos de §5 — son la fuente de verdad.*
