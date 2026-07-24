# Plan de Modularización con Vite — Arquitectura y Diseño

> **Versión viva.** Reemplaza a un borrador de proceso anterior. Este documento se enfoca en el **contexto arquitectónico,
> de diseño y de desarrollo**. El **flujo de trabajo** (ramas, PRs, reparto,
> tiempos) se define/ajusta en los chats especializados de flujo — aquí solo se
> menciona lo mínimo necesario y se marca como _sujeto a cambios_.

---

## 0. Objetivo y estrategia

Partir el `index.html` monolítico (~26.700 líneas originales) en módulos chicos
con **Vite**, **sin reescribir lógica** y **sin romper producción**. Es un
**refactor, no features**: mismo comportamiento, solo cambia _dónde vive_ el código.

**Estrategia maestra: extraer de afuera hacia adentro (fácil → difícil).**
El orden de extracción sigue un espectro de "acoplamiento":

> El diagrama clasifica por **dificultad** (con ejemplos de cada tipo); **no** es
> un cuadro de "hecho vs pendiente". De hecho, todos los ejemplos del izquierdo y
> medio **ya están extraídos** (Etapa 1 ✅); solo el extremo derecho queda diferido.

```
FÁCIL ──────────────────────────────────────────────────► DIFÍCIL
scalars          funciones puras    funciones c/estado    funciones acopladas
IVA ✅ ORG_ID ✅  escapeHtml ✅       dalBootTaxRates ✅    dalResolveIdentidad ⬜
identidad ✅      authPuedeVer ✅     supabaseInit ✅       dalLoadPermisos ⬜
un valor,        entra→sale,        tocan estado,         pegamento transversal:
sin deps         sin efectos        poca dep.             arrastran media app
└──────────────── ETAPA 1: HECHO ✅ ─────────────────┘    └─ ETAPA 2: diferido ─┘
```

- **Por dependencias:** los módulos *importan* el cimiento, no al revés → el
  cimiento va primero por obligación.
- **Por riesgo:** lo puro/simple es lo más seguro → se prueba el patrón en
  piezas inofensivas antes que en las peligrosas.

**Regla rol-vs-dificultad:** el plan organiza por *rol* (cimiento vs módulos),
pero la *ejecución* sigue la *dificultad*. Cuando chocan (una pieza es cimiento
por rol pero está muy acoplada), **gana la dificultad**: se extrae cuando su
entorno esté listo. (Caso real: los cargadores de identidad — ver §4.)

---

## 1. Patrones de diseño (el "cómo", reutilizable en cada corte)

### 1.1 Script clásico + puente a `window`
En la Etapa 0 el gran `<script>` inline se mantiene **clásico** (no `type="module"`).
Motivo (**Riesgo #1**): cargar el JS como módulo vuelve privadas las ~1.292
funciones y rompería los **876 `onclick` inline** (que solo buscan en el scope
global / `window`). En vez de exponer todo de golpe, se hace **incremental**:

- **El puente:** al mover una pieza a un módulo, se la re-expone en `window`
  (`window.fn = fn`) para que el código clásico y los `onclick` la sigan
  encontrando como global. El puente es **andamio temporal** (ver §5).
- **Verificación por corte:** cada extracción se prueba en staging antes de seguir.
  Si algo se rompe, fue _ese_ corte chico → reversión trivial.

### 1.2 Estado mutable a través de la frontera módulo/clásico
- **Objetos** (ej. `STATE`): se comparte la **misma referencia**
  (`window.STATE = STATE`). Leer/mutar `STATE.x` propaga solo. No se reasigna el
  objeto entero.
- **Scalars** (ej. `IVA`, `ORG_ID`): el **default** se fija en `window` al cargar
  el módulo. **Leer** es normal (al quitar el `let` del monolito, `IVA` resuelve a
  `window.IVA`). **Escribir** desde el monolito funciona solo (es **no-estricto** →
  global implícito); **escribir desde un módulo** debe ser `window.X = ...` (los
  módulos son **modo estricto**).
- **Internos:** lo que no usa nadie de afuera **no se expone** (ej.
  `MODULE_PERM_CODE`, `_toastId`).

### 1.3 Timing (módulos diferidos)
Los `<script type="module">` son **diferidos**: corren **después** de la ejecución
síncrona del bloque clásico, pero **antes** de `DOMContentLoaded`. Como la app
**arranca en `DOMContentLoaded`**, las piezas extraídas pueden usarse en runtime
sin problema. **Regla de seguridad por corte:** verificar que la pieza **no se use
a "columna 0"** (top-level, parse-time) antes de moverla.

### 1.4 Credenciales por entorno (sin filtrar staging a producción)
Las claves Supabase se inyectan por **modo de build** vía `import.meta.env`
(`.env.production` real, `.env.staging`). Cada build lleva **solo su propia base**:
producción **no** incluye staging. (En el HTML el mecanismo equivalente es
`%VITE_*%`, pero la fuente única son los `.env`.) Son **anon keys** (públicas por
diseño, protegidas por RLS); la `service_role` **jamás** va al cliente.

### 1.5 Rutas relativas (`base: './'`)
El build usa rutas **relativas**, así el mismo `dist/` funciona en cualquier
subcarpeta (`/Take-OS/`, `/takeos-staging/`). Esto, más el deploy automático,
**cierra el bug del 404** (deploy manual incompleto).

---

## 2. ETAPA 0 — Andamiaje Vite · ✅ HECHA (en staging)

- Vite 7 + Node 20 (`.nvmrc`). `index.html` movido a `frontend/`.
- 2 bloques de CSS de página → `frontend/src/styles.css` (los 16 `<style>` que son
  *strings de JS* se quedan en el JS).
- GitHub Action: push a `main` → `vite build` → publica `dist/` en Pages.
  El build elige modo por repo (staging usa `build:staging`).
- `base: './'` + credenciales por entorno (§1.4–1.5).
- **JS intacto**: sigue inline como script clásico (la modularización es Etapa 1+).
- **Producción NO migrada** (decisión deliberada, ver §6).

---

## 3. ETAPA 1 — Librería compartida `frontend/src/lib/` · ✅ CIMIENTO COMPLETO

El cimiento que **todos los módulos importan**. Estado actual:

| Módulo | Contenido | Estado |
|---|---|---|
| `helpers.js` | `escapeHtml`, `safeUrl`, `showToast` (+ internos) | ✅ |
| `supabase.js` | cliente `sb` + `supabaseInit` (creds vía `import.meta.env`) | ✅ |
| `rates.js` | tasas (`IVA`, `IMPUESTO_*`, `FACTOR_*`…) + `dalBootTaxRates` | ✅ |
| `state.js` | `STATE` (objeto) + `ORG_ID`, usuario, `TAKEOS_PERFIL/ACCESO`, identidad/sesión | ✅ |
| `auth.js` | helpers de permisos (`authNivel`, `authPuedeVer/Editar`, `authEsAdmin`, `MODULE_PERM_CODE`…) | ✅ (solo helpers) |
| `main.js` | punto de entrada: importa todo y lo puentea a `window` | ✅ |

**Cierre Etapa 1:** `src/lib` existe, `main.js` importa de ahí, app idéntica,
verde en staging. El **estado compartido está completo y coherente** en `state.js`.

---

## 4. Lo diferido a Etapa 2 (por dificultad, no por olvido)

Tres piezas de auth quedaron en el monolito **a propósito**, por la regla
rol-vs-dificultad (§0): son cimiento por rol pero están en el extremo **acoplado**
del espectro.

- **`cloudGate`** (overlay de login): es una **vista**, nadie la importa → se
  modulariza como una vista más en Etapa 2.
- **`dalResolveIdentidad` / `dalLoadPermisos`** (cargadores de identidad y
  permisos): escriben el estado (`TAKEOS_PERFIL/ACCESO`, identidad), pero están
  acoplados a **`BD_CONTACTOS`** (datos) y a **UI** (`renderTopbarUser`,
  `applyPermisosUI`, `setCurrentUser`→`renderMetrics`/`renderKanban`). Extraerlos
  ahora arrastraría la capa de datos + UI (cascada). Se extraen **limpio** cuando
  esos vecinos se modularicen (corte "boot/identidad" temprano en Etapa 2).
- **Sesión** (`logoutTakeOS`, `AUTH_TTL`, tokens en localStorage) + appliers de
  permisos a UI (`applyPermisosUI`, `_firstVisibleModule`, `applyModuleReadonly`):
  van con el login/su entorno.

> El **estado** que estas funciones escriben ya vive en `state.js`; ellas escriben
> a `window.X` desde el monolito (no-estricto). Que las **funciones** sigan en el
> monolito **no** complica la extracción de los módulos de Etapa 2 (los módulos
> *leen* estado, no escriben identidad).

---

## 5. ETAPA 2 — Módulos de negocio · ⬜ PENDIENTE

Partir los módulos de dominio a `frontend/src/modules/` (Proyectos/Kanban,
Finanzas/CFO, Cotización, Legal, Plan de Rodaje, Hoja de Llamado, Notificaciones…),
más las piezas de auth diferidas (§4).

**Cada módulo tiene su propio mini-espectro** (sus helpers puros → su estado → su
UI): se descompone igual que el todo. Mismo ciclo por corte: extraer → puente a
`window` → build → verificar en staging.

*(El reparto de módulos y el flujo de PRs se define en los chats de flujo.)*

---

## 6. Despliegue, divergencia y seguridad (contexto que condiciona el diseño)

- **Dos repos independientes** (sin historia compartida): `Take-OS` (producción,
  monolito) y `takeos-staging` (el trabajo Vite). A **staging** se publica con
  push directo a su `main`; a **producción** se irá por PR.
- **Producción sigue en el monolito** hasta un **cutover único** más adelante. Por
  eso: **no parchar el `index.html` de prod**; todo el frontend nuevo pasa por la
  rama Vite. Cuando prod recibe features (PRs), llegan como **handoff** y se
  aplican **a mano** a la rama Vite (no merge), como commit `Feature (handoff …)`.
  Ya reconciliado: PR #2 "tope de colaboradores por proyecto".
- **Objetivo final de seguridad:** eliminar `'unsafe-inline'` del CSP. Hoy es
  obligatorio porque la app es 100% inline (el `<script>` + 876 `onclick`); mientras
  esté, el CSP no frena XSS inline. Camino: modularizar → reemplazar `onclick`
  inline por `addEventListener` en módulos → quitar los puentes a `window` → recién
  ahí quitar `'unsafe-inline'`. Esa es la verdadera defensa contra XSS, y solo es
  posible **después** de modularizar.
- Pendientes operativos: ver [PENDIENTES_Migracion_Vite.md](PENDIENTES_Migracion_Vite.md)
  (diagnóstico del "404" real, cutover de producción).

---

## 7. Glosario rápido (para alinear lenguaje)

- **Puente / bridge:** `window.fn = fn` — re-exponer en el global algo que se movió
  a un módulo, para no romper el código clásico / los `onclick`.
- **Scalar:** un valor único (número/texto/bool), sin dependencias → fácil de mover.
- **Acoplado a UI:** lógica que toca la pantalla (DOM) directamente → difícil de
  mover (arrastra render functions).
- **Modo estricto:** los módulos ES lo son; no permiten reasignar un global sin
  declarar (por eso las escrituras desde módulos van por `window.X`).
- **Cimiento:** lo que todos los módulos importan (estado, db, utilidades,
  permisos). Por definición, de bajo acople.
