# TakeOS — Modularización con Vite · Resumen técnico y handoff

> **Para quién es esto:** alguien que llega **sin contexto** y necesita entender la
> arquitectura, qué cambió en la estructura, cómo está montado el desarrollo y cómo
> seguir. Asume conocimiento de JS/web pero **no** de este proyecto.

---

## 1. TL;DR

TakeOS era **un solo archivo** `index.html` (~26.700 líneas) con todo dentro: HTML +
18 bloques `<style>` + ~1.292 funciones JS inline + 876 manejadores `onclick=""`
inline. Lo estamos partiendo en **módulos ES** con **Vite**, **sin reescribir
lógica** y **sin romper producción**, de forma **incremental** (una pieza por commit,
verificando en staging cada una).

La técnica central es el **"puente a `window`"**: cada función que se mueve a un
módulo se vuelve a exponer en `window` para que el código que aún vive en el monolito
(y los `onclick` inline) la siga encontrando como global.

**Estado:** Etapa 0 (andamiaje) ✅ · Etapa 1 (cimiento `src/lib`) ✅ · Etapa 2
(módulos de negocio) ⬜ pendiente (es el ~88% del trabajo).

---

## 2. Por qué la migración no es trivial (el "Riesgo #1")

En el navegador, el HTML conecta botones con lógica mediante atributos **inline**:

```html
<button onclick="notifMarcarTodas()">Marcar todas como leídas</button>
```

Cuando el usuario hace clic, el navegador busca `notifMarcarTodas` **en el objeto
global `window`** y la ejecuta. Hoy eso funciona porque el JS es un **script clásico**
(`<script>...</script>`), y en modo clásico **toda función declarada en el nivel
superior queda automáticamente colgada de `window`**.

El problema: un **módulo ES** (`<script type="module">`) tiene **scope propio**. Una
`function foo(){}` definida en un módulo **NO** queda en `window`. Si moviéramos el JS
a módulos sin precaución, los 876 `onclick` dejarían de encontrar sus funciones y los
botones **se romperían en silencio** (sin error visible).

**Solución adoptada:** mantener el monolito como **script clásico** y mover piezas a
módulos **una por una**, **re-exponiéndolas en `window`** (el "puente").

---

## 3. El mecanismo central: el "puente a `window`"

### Antes (todo en el monolito, clásico)
```js
// dentro del gran <script> de index.html
function escapeHtml(s) { /* ... */ }   // clásico ⇒ queda en window automáticamente
// ...y 659 llamadas a escapeHtml(...) repartidas por el archivo
```

### Después (la función vive en un módulo)
```js
// frontend/src/lib/helpers.js  (módulo ES, scope privado)
export function escapeHtml(s) { /* ... */ }
```
```js
// frontend/src/main.js  (módulo entry)
import { escapeHtml } from './lib/helpers.js';
window.escapeHtml = escapeHtml;   // ← EL PUENTE: la re-expone como global
```
En `index.html` se **borra** la definición vieja. Las 659 llamadas siguen escribiendo
`escapeHtml(...)`; al no existir ya una definición local, ese identificador **resuelve
a `window.escapeHtml`** (que el módulo dejó puesto). Botones intactos.

> El puente es **andamio temporal**. Desaparece al final de la migración (ver §11).

### Reglas según el tipo de pieza
| Tipo | Cómo se mueve | Ejemplo |
|---|---|---|
| **Función** | `window.fn = fn` (puente en `main.js` o auto-puente en el módulo) | `escapeHtml`, `authPuedeVer` |
| **Objeto mutable** | compartir la **misma referencia**: `window.OBJ = OBJ`; mutar `OBJ.x` propaga | `STATE` |
| **Scalar mutable** | default en `window` (`window.IVA = 0.19`); **leer** normal; **escribir desde módulo** debe ser `window.IVA = ...` (modo estricto) | `IVA`, `ORG_ID` |
| **Interno** (nadie externo lo usa) | **no se expone** | `MODULE_PERM_CODE`, `_toastId` |

### Dos detalles técnicos que importan
1. **Modo estricto:** los módulos ES son siempre estrictos → no se puede reasignar un
   global no declarado (`IVA = x` lanza error). Por eso las **escrituras desde un
   módulo** van por `window.IVA = x`. El monolito es **no-estricto**, así que sus
   escrituras a globales no declarados funcionan (global implícito = `window.X`).
2. **Timing (módulos diferidos):** `<script type="module">` se ejecuta **después** del
   parseo síncrono del script clásico, pero **antes** de `DOMContentLoaded`. La app
   arranca en `DOMContentLoaded`, así que las piezas movidas están disponibles a
   tiempo. **Regla por corte:** verificar que la pieza **no se use a "columna 0"**
   (código top-level que corre durante el parseo) antes de moverla.

---

## 4. Estructura del repo (después de Etapa 0 + 1)

```
Take-OS/                         # repo de PRODUCCIÓN (monolito; aún no migrado)
├── index.html                   # (en main) el monolito original, en la raíz
├── docs/Planes/
│   ├── Plan_Modularizacion_Vite.md      # plan arquitectónico
│   ├── PENDIENTES_Migracion_Vite.md     # pendientes (404 real, cutover)
│   └── RESUMEN_Sesion_Modularizacion.md # este documento
├── supabase/migrations/         # backend (no es parte de la migración frontend)
└── frontend/                    # ← la app Vite (donde vive el trabajo)
    ├── index.html               # el monolito MOVIDO aquí; va perdiendo piezas
    ├── package.json             # scripts npm (ver §5)
    ├── vite.config.js           # base: './'  (rutas relativas)
    ├── .nvmrc                    # 20  (Node LTS)
    ├── .env.production           # VITE_SUPABASE_URL/KEY de la base REAL
    ├── .env.staging             # VITE_SUPABASE_URL/KEY de la base de STAGING
    └── src/
        ├── main.js              # ENTRY: importa src/lib y puentea a window
        ├── styles.css           # 2 bloques de CSS de página (extraídos en Etapa 0)
        └── lib/                 # EL CIMIENTO (Etapa 1)
            ├── helpers.js
            ├── supabase.js
            ├── rates.js
            ├── state.js
            └── auth.js
```

`index.html` carga, en orden: los `<script src>` de CDN (xlsx, supabase-js), luego
`<script type="module" src="/src/main.js">`, luego el gran `<script>` clásico inline.

---

## 5. Sistema de build (Vite) y comandos

`frontend/package.json` (scripts):
```json
{
  "scripts": {
    "dev": "vite --mode staging",          // dev local → usa .env.staging
    "build": "vite build",                  // build PRODUCCIÓN → usa .env.production
    "build:staging": "vite build --mode staging",  // build STAGING
    "preview": "vite preview"               // sirve el dist/ ya construido
  }
}
```

`frontend/vite.config.js`:
```js
export default defineConfig({
  base: './',              // rutas relativas → sirve en /Take-OS/ y /takeos-staging/
  build: { outDir: 'dist' }
});
```

**Flujo local típico:**
```bash
cd frontend
nvm use                 # Node 20 (de .nvmrc)
npm install
npm run build:staging   # o: npm run dev
npm run preview         # abre http://localhost:4173/
```

---

## 6. Credenciales por entorno (sin filtrar staging a producción)

Las claves Supabase se inyectan **en build, por modo**:
- `.env.production` → base real → lo usa `npm run build`.
- `.env.staging` → base de staging → lo usa `npm run build:staging` y `npm run dev`.

En los **módulos** se leen con `import.meta.env.VITE_SUPABASE_URL` (Vite las reemplaza
por el valor del `.env` del modo activo). Resultado verificado: **el build de
producción NO contiene la URL de staging** y viceversa. Son *anon keys* (públicas por
diseño, protegidas por RLS); la `service_role` **jamás** va al cliente.

> Nota: en el HTML el mecanismo equivalente sería `%VITE_*%`, pero al pasar a módulos
> se usa `import.meta.env`. Misma fuente (`.env`), distinto punto de lectura.

---

## 7. Despliegue (GitHub Pages + Action)

**Dos repos GitHub, independientes (sin historia compartida):**
- `agustinmunozrocha/Take-OS` → **producción** (sirve el monolito; aún no migrado).
- `agustinmunozrocha/takeos-staging` → **staging** (sirve el build de Vite).

`.github/workflows/deploy.yml`: en cada push a `main`, hace `npm ci` + build y publica
`frontend/dist/` en Pages. Elige el modo según el repo:
```yaml
- name: Build
  run: |
    if [ "${{ github.repository }}" = "agustinmunozrocha/takeos-staging" ]; then
      npm run build:staging      # staging → base de staging
    else
      npm run build              # producción → base real
    fi
```
`base: './'` + deploy automático completo = **cierra el bug del "404"** del deploy
manual (subidas incompletas).

**Cómo se publica a cada uno (workflow de la migración):**
- **Staging:** push directo a su `main` (sin dejar ramas):
  `git push staging <rama-local>:main --force`
- **Producción:** se hará por **Pull Request** (cutover diferido; aún no hecho).

Remotos en el clon local:
```
origin   → github.com/agustinmunozrocha/Take-OS          (prod)
staging  → github.com/agustinmunozrocha/takeos-staging   (Vite)
```

---

## 8. Qué hay en cada módulo de `src/lib` (Etapa 1)

| Módulo | Exporta / expone | Internos (no se exponen) | Notas técnicas |
|---|---|---|---|
| `helpers.js` | `escapeHtml`, `safeUrl`, `showToast` | `_toastId`, `stripControlChars` | `safeUrl` llama a `escapeHtml` directo (mismo módulo). `stripControlChars` reemplaza la regex unicode original (evita corrupción de escapes `\u`). `showToast` toca el DOM (`#toastContainer`). |
| `supabase.js` | `supabaseInit` (y `window.sb` al iniciar) | `SUPABASE_URL/KEY`, `sb` | Credenciales vía `import.meta.env`. `supabaseInit()` crea el cliente y hace `window.sb = sb`. El monolito usa `sb` en ~115 lugares (resuelve a `window.sb`). |
| `rates.js` | `dalBootTaxRates` | — (los defaults van directo a `window`) | Estado mutable: `window.IVA`, `window.IMPUESTO_HONORARIOS`, `window.IMPUESTO_BTE`, `window.FACTOR_BOLETA`, `window.FACTOR_BTE`, `window.TAX_RATES_SOURCE`. `dalBootTaxRates` los sobrescribe vía `window.X` con datos de la tabla `tax_rates`. |
| `state.js` | `STATE` (objeto) | — (los scalars van directo a `window`) | `STATE` se comparte por referencia. Scalars en `window`: `ORG_ID`, `USER_NOMBRE`, `USER_APELLIDO`, `TAKEOS_PERFIL`, `TAKEOS_ACCESO`, `DAL_SESSION_UID`, `DAL_SESSION_EMAIL`, `USUARIO_ACTUAL`. Las **funciones** que los escriben siguen en el monolito (ver §10). |
| `auth.js` | `authNivel`, `authNivelModulo`, `authPuedeVer`, `authPuedeEditar`, `authEsAdmin`, `_puedeEditarResponsables`, `_puedeEditarTareas`, `authPuedeGuardarProyecto`, `authPuedeGuardarOperaciones`, `_authBlockWriteToast` | `MODULE_PERM_CODE`, `_authBlockToastAt` | **Auto-puente**: el módulo hace `window.fn = fn` al final (no se puentea desde `main.js`). Leen `TAKEOS_ACCESO/PERFIL` y `showToast` desde `window`. |

`src/main.js` (entry, estado actual):
```js
import { escapeHtml, safeUrl, showToast } from './lib/helpers.js';
import { supabaseInit } from './lib/supabase.js';
import { dalBootTaxRates } from './lib/rates.js';
import { STATE } from './lib/state.js';
import './lib/auth.js';                 // side-effect: se auto-puentea

window.escapeHtml = escapeHtml;
window.safeUrl = safeUrl;
window.showToast = showToast;
window.supabaseInit = supabaseInit;     // al llamarse, setea window.sb
window.dalBootTaxRates = dalBootTaxRates;
window.STATE = STATE;                    // mismo objeto compartido
```

---

## 9. Receta para una nueva extracción (cada "corte")

1. **Inspeccionar** la pieza en `index.html`: ¿qué es (scalar/función pura/función con
   estado/acoplada a UI)? ¿de qué depende? ¿quién la escribe?
2. **Timing:** confirmar que **no se use a columna 0** (top-level/parse-time).
3. **Mover** el código verbatim a su módulo en `src/lib/` (refactor, no features).
4. **Puente:** `window.fn = fn` en `main.js` (o auto-puente en el módulo).
   - Mutable scalar: default en `window` + escrituras del módulo vía `window.X`.
   - Objeto: `window.OBJ = OBJ` (misma referencia).
5. **Borrar** la definición vieja del monolito.
6. **Verificar:** `npm run build:staging` + chequeos estructurales (la pieza salió del
   clásico, está en el bundle, los usos siguen). Si es pura, además test en Node.
7. **Commit** (mensaje claro: qué pieza y por qué).
8. **Push a staging** + **verificación funcional** en la URL real.

> Chequeos útiles tras el build: `grep -c "function X" dist/index.html` (→ 0),
> `grep -oE "function [a-zA-Z0-9_]+\(" dist/index.html | wc -l` (conteo de funciones).

---

## 10. Diferido a Etapa 2 (decisión deliberada, no olvido)

Estas piezas son "cimiento por rol" pero están **muy acopladas** → se extraen con sus
vecinos en Etapa 2 (regla **rol-vs-dificultad**):

- **`cloudGate`** — overlay de login. Es una **vista**, nadie la importa.
- **`dalResolveIdentidad` / `dalLoadPermisos`** — cargadores de identidad/permisos.
  Escriben el estado (`TAKEOS_PERFIL/ACCESO`, identidad) **pero** dependen de
  `BD_CONTACTOS` (datos) y de UI (`renderTopbarUser`, `applyPermisosUI`,
  `setCurrentUser`→`renderMetrics`/`renderKanban`). Extraerlos hoy arrastraría la capa
  de datos + UI (cascada).
- **Sesión** (`logoutTakeOS`, `AUTH_TTL`) + appliers de permisos a UI
  (`applyPermisosUI`, `_firstVisibleModule`, `applyModuleReadonly`).

> El **estado** que esas funciones escriben **ya está en `state.js`**; ellas escriben
> a `window.X` desde el monolito. Que las **funciones** sigan en el monolito **no**
> complica la Etapa 2 (los módulos de negocio *leen* estado, no escriben identidad).

---

## 11. Objetivo final de seguridad (CSP)

El CSP vive como `<meta http-equiv="Content-Security-Policy">` en `index.html`
(línea ~35; está como `<meta>` porque GitHub Pages es estático y no permite cabeceras
HTTP). Hoy **obliga** a `script-src ... 'unsafe-inline'` porque la app es 100% inline
(el `<script>` clásico + 876 `onclick`). `'unsafe-inline'` debilita la defensa contra
**XSS** (el navegador no distingue tu inline del inline inyectado por un atacante).

**Camino para cerrarlo (post-migración):** modularizar → reemplazar `onclick` inline
por `addEventListener` dentro de módulos → quitar los puentes a `window` → recién ahí
quitar `'unsafe-inline'`. Solo entonces el navegador bloquea inyecciones inline.

---

## 12. Divergencia prod ↔ Vite (handoffs)

Producción (monolito) sigue evolucionando mientras migramos. Regla:
- **No parchar** el `index.html` de producción directamente.
- Cuando prod recibe una feature (PR), llega como **handoff** y se aplica **a mano** a
  la rama Vite (NO `git merge` del monolito), como commit `Feature (handoff ...)`.
- **Ya reconciliado:** PR #2 "tope de colaboradores POR PROYECTO" (Cargos): contador
  "N/Y colaboradores", cartel "sube de plan" al tope, lee `plan_catalog.max_colaboradores`.
  Aplicado en `index.html` (las funciones de Cargos son de Etapa 2, aún no extraídas).

---

## 13. Progreso real (foto honesta)

- **Funciones:** 12 extraídas a `src/lib` de ~1.290 → **<1%** modularizado.
- **Líneas del monolito:** 26.685 → **23.369** (~12% menos; buena parte fue el CSS).
- **Funciones que siguen en `index.html`:** ~1.278.
- **Interpretación:** se construyó el **cimiento** (lo que todos importan), que es
  chico en volumen pero **destraba** todo. **Etapa 2 (módulos de negocio) es ~88% del
  trabajo restante** y es lo que ahora se puede repartir en paralelo.

---

## 14. Historial de commits (rama `etapa1-lib`)

```
1893838  Etapa 1 · state.js: scalars de identidad/sesion -> cimiento completo
b608c06  Etapa 1 · auth.js (1/?): helpers de permisos
62f3796  Feature (handoff PR #2): tope de colaboradores POR PROYECTO
60daacc  Etapa 1 · state.js: scalars de estado (ORG_ID, usuario, perfil, acceso)
7ff7089  Etapa 1 · state.js: objeto STATE global
5dff8bb  Etapa 1 · rates.js: tasas tributarias (primer estado mutable)
bcbd0ba  Etapa 1 · supabase.js: cliente sb + supabaseInit
682f4e8  Etapa 1 · showToast -> helpers.js
b950d8f  Etapa 1 · safeUrl -> helpers.js
dd24ab1  Etapa 1 · escapeHtml -> helpers.js
fd49a86  Etapa 1 · Paso 0: punto de entrada de módulos
```

**Ramas locales:**
- `main` — intacta (= prod, monolito en la raíz).
- `pre-vite` — foto de rollback del main pre-migración.
- `vite-andamiaje` — base con la Etapa 0.
- `etapa1-lib` — rama de trabajo actual (Etapa 1).

---

## 15. Próximos pasos

1. **SYNC con Agustín:** mostrar `src/lib` + la regla del puente + acordar reparto de
   módulos de Etapa 2.
2. **Etapa 2:** extraer módulos de negocio a `frontend/src/modules/` (cada uno con su
   propio mini-espectro: helpers puros → estado → UI), mismo ciclo de la §9.
3. Diagnosticar el **"404" real** de prod (documentar el incidente concreto).
4. **Cutover de producción:** PR a `Take-OS`, activar Pages→Actions, merge, verificar,
   con rollback a `pre-vite` listo.
5. (Más adelante) cargadores de identidad + login `cloudGate` + sesión.

---

## 16. Glosario

- **Monolito:** el `index.html` gigante con todo dentro.
- **Puente / bridge:** `window.fn = fn` — re-exponer en el global algo movido a un
  módulo, para no romper el código clásico / los `onclick`.
- **Script clásico vs módulo:** clásico = sus funciones quedan en `window` solas;
  módulo = scope privado + modo estricto, solo expone lo que pone `export`/`window.X`.
- **Scalar:** un valor único (número/texto/bool), sin dependencias → fácil de mover.
- **Acoplado a UI:** lógica que toca el DOM directamente → difícil de mover (arrastra
  funciones de render).
- **Columna 0 / parse-time:** código que corre durante el parseo del script (no dentro
  de funciones) → riesgo de timing con módulos diferidos.
- **Cimiento:** lo que todos los módulos importan (estado, db, utilidades, permisos).
- **Cutover:** el momento de cambiar producción del monolito a la versión Vite.
```
