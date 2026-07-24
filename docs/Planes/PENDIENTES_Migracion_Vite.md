# Pendientes importantes — Migración a Vite

> Documento vivo. Recoge decisiones y temas abiertos de la migración del monolito
> (`index.html`) a una app modular con Vite. Revisar antes de cada etapa.

**Contexto general:** la Etapa 0 (andamiaje Vite + deploy automático + base por
entorno) está **hecha y verificada en staging**, pero **NO se ha desplegado a
producción (Take-OS)** todavía. Producción sigue corriendo el monolito viejo con
deploy manual. El cutover a producción se hará más adelante, en un solo paso.

---

## 1. El "404" de producción — pendiente de diagnóstico + arreglo

**Qué es (hasta donde sabemos):** un fallo **intermitente que aparece al publicar
a mano**. El deploy de Take-OS hoy es manual (subida de archivos por la web), y un
despliegue puede quedar incompleto (archivo que no subió, subida a medias, rutas
que no calzan con la subcarpeta del sitio). Cuando eso pasa, el sitio queda en
"404 / Not Found" hasta que alguien lo corrige a mano. **No es un estado roto
permanente** — producción hoy funciona; es un **riesgo que reaparece en cada
deploy manual**. En el historial de staging se vio un deploy fallido (rojo), que
es justo este tipo de tropiezo.

**Pendiente real (por confirmar con quien lo vivió):**
- [ ] Describir el incidente concreto: ¿la página entera daba 404 o cargaba a
      medias/en blanco (assets faltantes)? ¿Con qué frecuencia? ¿Tras qué acción?
- [ ] Confirmar que la solución de abajo ataca ese caso puntual.

**Solución ya construida (en la rama Vite, probada en staging):**
1. **Deploy automático** (GitHub Action): construye la app completa y publica
   todo `dist/` igual, cada vez, sin pasos manuales que se olviden.
2. **Rutas relativas** (`base: './'` en Vite): los assets funcionan en cualquier
   subcarpeta (`/Take-OS/` o `/takeos-staging/`), eliminando los 404 por rutas.

**Acción futura:** al hacer el **cutover de producción**, prod hereda el deploy
automático + rutas relativas, y este riesgo desaparece para siempre. Antes del
cutover, documentar el 404 real (checklist de arriba).

---

## 2. No parchar el monolito desplegado en Take-OS

**Decisión:** mientras no se haga el cutover, producción (`Take-OS`, rama `main`)
se queda con el **monolito viejo** (`index.html` en la raíz). Todo el trabajo
nuevo de frontend vive en la **rama Vite** y se prueba en **staging**.

**Riesgo a evitar:** si se edita el frontend del monolito **directamente en
Take-OS** mientras desarrollamos en la rama Vite, las dos versiones **divergen**.
Reconciliarlas después es doloroso (el `index.html` tiene ~26.700 líneas).

**Regla de trabajo (mientras dure la migración):**
- ✅ **Todo cambio de frontend pasa por la rama Vite** (`vite-andamiaje` y sus
  ramas hijas), y se despliega/prueba en staging.
- ❌ **No editar el `index.html` del monolito en producción.**
- ➡️ Excepción: cambios de **backend / SQL** (migraciones Supabase) no chocan con
  el frontend; pueden seguir su flujo normal.

**Al momento del cutover:** la rama Vite **reemplaza** el monolito en producción.
Si por alguna razón hubo un hotfix urgente directo en prod, hay que **portarlo a
la rama Vite antes** del cutover para no perderlo.

---

## Estado de despliegue (referencia rápida)

| Entorno | Qué corre hoy | Deploy |
|---|---|---|
| **Take-OS** (producción) | monolito viejo | manual (pendiente cutover a Vite) |
| **takeos-staging** | build de Vite ✅ | automático (GitHub Action) |
| Rama `vite-andamiaje` (local + staging) | base de todo el trabajo nuevo | — |
