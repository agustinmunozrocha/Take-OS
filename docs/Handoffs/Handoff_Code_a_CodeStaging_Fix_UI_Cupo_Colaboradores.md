# Handoff — Code (producción) → Code (staging, equipo de Juan)
## Aplicar el fix de UI del "límite de colaboradores POR PROYECTO" al frontend modularizado de staging

**De:** Code (trabaja el monolito `index.html` de producción)
**Para:** Code que trabaja el frontend de staging con Juan
**Vía:** Agustín → Juan
**Fecha:** 19-jun-2026
**Tipo:** refactor-safe (no cambia comportamiento salvo el manejo del tope que se describe acá)

---

## 0. ⭐ Instrucción especial para ti (Code de staging)

Cuando apliques esto, **explícale a Juan en "peras y manzanas"** (sin jerga) qué hiciste y qué cambia para el usuario. Resumen que le puedes dar:

> En la pestaña **Cargos** de un proyecto ahora se ve un contador **"N / Y colaboradores"**. Cuando el proyecto llega a su tope (según el plan de la productora), al intentar **agregar otro cargo** aparece un cartel sobrio de *"sube de plan"* (en vez de dejar agregar y fallar al guardar). Y si igual se topa al guardar, sale el mismo cartel en vez de un error feo. Nada más cambia: es el mismo software, solo ordenado y con el aviso del límite bien puesto.

---

## 1. Contexto (qué y por qué)

- En **producción**, el límite de colaboradores del plan pasó a ser **POR PROYECTO** (= número de personas en la pestaña **Cargos** de ESE proyecto), ya no la suma de toda la organización. La parte de base de datos ya está viva (migración `20260617160000_fix_cupo_colaboradores_por_proyecto`) **y también en la branch de staging** (el BD Expert la dejó sembrada con casos al tope; ver §4).
- **Contrato con la base** (no cambia, solo para que sepas con qué hablas):
  - La RPC `guardar_cargos(p_project_id, p_cargos)` lanza el error tipado **`TAKEOS_PLAN_LIMITE:colaboradores:<N>`** si el arreglo de cargos supera el máximo del plan (`<N>` = tope: 4 o 12).
  - `invitar_a_organizacion` **ya NO mide cupo** (el límite vive solo en `guardar_cargos`).
  - El tope por plan vive en **`plan_catalog.max_colaboradores`** (`free`=4, `rodaje`=4, `produccion`=12). El cliente autenticado **puede leer** `plan_catalog` y `organizations` (verificado: `has_table_privilege('authenticated', …) = true`).
- En el **monolito de producción** el frontend ya acompaña esto (PR #2, commits `c1a0e5a` + `f4cd189`). **Tu tarea es replicar esos 5 cambios en la versión modularizada de staging.**

> ⚠️ **No hagas un merge del monolito.** Tu frontend está reestructurado (Vite); un merge chocaría feo. Aplica los 5 cambios **a mano**, en los archivos/módulos donde ahora vivan esas funciones.

---

## 2. Funciones que toca (búscalas en tu estructura nueva)

`dalGuardarCargos`, `renderCargos`, `cargoAbrirModal`, `manejarErrorPlan` (+ `_planModalVenta`), y dependes de estos globales/módulos: `sb` (cliente Supabase), `PROJECTS_SOURCE`, `ORG_ID` (org activa), `STATE.currentModule`, `ensureCargos(project)`, `_puedeAsignarCargos()`, `_cargoPill(txt, tone)`. Cabléalos a donde estén ahora (imports, etc.).

---

## 3. Los 5 cambios (código exacto)

### 3.1 — Helper nuevo + cache del tope (ponlo en la lib/módulo de cargos)
Lee el tope del plan de la org activa desde la base. Cache por org; `null` = desconocido → no bloquea proactivamente (el server-side sigue siendo la red de seguridad).
```js
let _TOPE_COLAB = null;
let _TOPE_COLAB_ORG = null;
async function dalCargarTopeColaboradores() {
  if (!sb || PROJECTS_SOURCE !== 'supabase') return null;
  if (_TOPE_COLAB != null && _TOPE_COLAB_ORG === ORG_ID) return _TOPE_COLAB;
  try {
    const { data: org, error: e1 } = await sb.from('organizations').select('plan').eq('id', ORG_ID).single();
    if (e1) throw e1;
    const plan = (org && org.plan) ? org.plan : null;
    if (!plan) return null;
    const { data: pc, error: e2 } = await sb.from('plan_catalog').select('max_colaboradores').eq('codigo', plan).single();
    if (e2) throw e2;
    _TOPE_COLAB = (pc && pc.max_colaboradores != null) ? pc.max_colaboradores : null;
    _TOPE_COLAB_ORG = ORG_ID;
    return _TOPE_COLAB;
  } catch (e) {
    console.warn('[plan] no se pudo leer el tope de colaboradores', e);
    return null;
  }
}
```

### 3.2 — `dalGuardarCargos`: enrutar el error de tope por el cartel de plan
En el `catch`, **antes** del toast genérico de "Cargos sin sincronizar", agrega:
```js
    if (manejarErrorPlan(e)) return false;   // tope de colaboradores por proyecto → cartel "sube de plan"
```

### 3.3 — `manejarErrorPlan`: corregir el texto del recurso `'colaboradores'`
La rama `else if (rec === 'colaboradores')` tenía un texto viejo ("…contando las invitaciones pendientes"). Reemplázalo por:
```js
    else if (rec === 'colaboradores') _planModalVenta('Tope de colaboradores de tu plan', 'Tu plan permite hasta ' + max + ' personas en la pestaña Cargos de un proyecto. Quita a alguien de Cargos para liberar un cupo, o cambia de plan para subir el tope.');
```

### 3.4 — `renderCargos`: cargar el tope (diferido) y pintar el contador "N / Y"
Después de obtener `cargos` y `puede`, agrega la carga diferida + las variables del contador:
```js
  // tope de colaboradores por proyecto (carga diferida + cache)
  if (_TOPE_COLAB == null || _TOPE_COLAB_ORG !== ORG_ID) {
    dalCargarTopeColaboradores().then(function (t) { if (t != null && STATE.currentModule === 'cargos') renderCargos(); });
  }
  const _topeColab = (_TOPE_COLAB != null && _TOPE_COLAB_ORG === ORG_ID) ? _TOPE_COLAB : null;
  const _nColab = cargos.length;
  const _enTope = (_topeColab != null && _nColab >= _topeColab);
  const _contadorColab = _topeColab != null
    ? '<span style="font-size:12px;font-weight:600;color:' + (_enTope ? '#A71E26' : 'var(--ink-faint)') + ';" title="Colaboradores de este proyecto (las personas en Cargos) contra el tope de tu plan.">' + _nColab + ' / ' + _topeColab + ' colaboradores</span>'
    : '<span style="font-size:12px;color:var(--ink-faint);">' + _nColab + (_nColab === 1 ? ' colaborador' : ' colaboradores') + '</span>';
```
Y en el encabezado de la tabla, mete `_contadorColab` junto a las pastillas de leyenda. En el monolito el cambio fue:
```js
// ANTES:
+ '<div style="display:flex;gap:8px;align-items:center;">' + _cargoPill('● interno', 'int') + ' ' + _cargoPill('● externo', 'ext') + '</div>'
// DESPUÉS:
+ '<div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap;">' + _cargoPill('● interno', 'int') + ' ' + _cargoPill('● externo', 'ext') + ' ' + _contadorColab + '</div>'
```

### 3.5 — `cargoAbrirModal`: bloqueo proactivo al AGREGAR
Justo después de calcular `edit` (y antes de armar el modal), agrega:
```js
  // bloqueo proactivo del tope por proyecto (solo al AGREGAR, no al editar)
  if (!edit && _TOPE_COLAB != null && _TOPE_COLAB_ORG === ORG_ID && cargos.length >= _TOPE_COLAB) {
    _planModalVenta('Tope de colaboradores de tu plan', 'Este proyecto ya tiene ' + cargos.length + ' personas en Cargos, el máximo de tu plan. Quita a alguien de Cargos para liberar un cupo, o cambia de plan para subir el tope.');
    return;
  }
```

---

## 4. Detalles que importan (no te los saltes)
- **El contador cuenta `cargos.length`** (todas las filas de Cargos), que es **exactamente** lo que cuenta la base. NO membresías, NO admin/CFO por su rol. Así el "N/Y" coincide al pelo con cuándo bloquea el servidor.
- **El tope se LEE de `plan_catalog`** — no lo hardcodees (vive en la base, igual que las tasas de impuesto).
- **Degradación con gracia:** si por algo no se puede leer el tope, el contador muestra solo "N colaboradores" (sin "/Y") y el guardado server-side (3.2) sigue protegiendo. Nunca rompe.
- Reutiliza el `manejarErrorPlan` / `_planModalVenta` que ya existan en tu base (no dupliques el manejo de carteles de plan).

---

## 5. Prueba en staging (datos ya sembrados por el BD Expert)
- **Highgarden** (plan Rodaje, tope 4) · proyecto `PR-HIG-0004` ya en **4/4** → "+ Asignar un cargo" debe mostrar el cartel; en otro proyecto con espacio, deja agregar normal.
- **Rivendell** (plan Producción, tope 12) · `PR-RIV-0004` en **12/12** → corta en el 13º.
- **Gondor** (plan Free, tope 4) → igual que Rodaje.
- Verificar el contador **"N / Y colaboradores"** (rojo al llegar al tope) y que **un proyecto al tope no afecta a otro** de la misma productora (cada uno cuenta por separado).

---

## 6. Diff de referencia (del monolito de producción, PR #2)
Por si quieres ver el cambio íntegro y sus posiciones originales:
```diff
@@ async function dalGuardarCargos(project) {  (catch)
     console.error('[dal] guardar cargos', e);
+    if (manejarErrorPlan(e)) return false;
     try { showToast({ kind: 'warning', title: 'Cargos sin sincronizar', ... }); } catch (x) {}
     return false;
@@ (función nueva, tras dalGuardarCargos)
+ let _TOPE_COLAB = null; let _TOPE_COLAB_ORG = null;
+ async function dalCargarTopeColaboradores() { … }   // §3.1
@@ function renderCargos()  (tras const cargos / const puede)
+ // carga diferida del tope + _contadorColab   // §3.4
@@ renderCargos header
- '<div style="display:flex;gap:8px;…">' + _cargoPill('● interno','int') + ' ' + _cargoPill('● externo','ext') + '</div>'
+ '<div style="display:flex;gap:10px;…flex-wrap:wrap;">' + _cargoPill('● interno','int') + ' ' + _cargoPill('● externo','ext') + ' ' + _contadorColab + '</div>'
@@ function cargoAbrirModal(editId)  (tras const edit)
+ if (!edit && _TOPE_COLAB != null && _TOPE_COLAB_ORG === ORG_ID && cargos.length >= _TOPE_COLAB) { _planModalVenta(…); return; }   // §3.5
@@ function manejarErrorPlan(err)  (rama 'colaboradores')
- '…hasta ' + max + ' colaboradores, contando las invitaciones pendientes. Para sumar más, cambia de plan.'
+ '…hasta ' + max + ' personas en la pestaña Cargos de un proyecto. Quita a alguien de Cargos… o cambia de plan…'
```

---

*Handoff efímero — una vez aplicado en staging, descártalo. Commits de origen en Take-OS: `c1a0e5a` + `f4cd189` (PR #2).*
