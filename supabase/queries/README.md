# supabase/queries

Queries SQL **reutilizables** del proyecto. Esta carpeta es independiente de
`supabase/migrations/` y **el Supabase CLI no la toca**: no se aplican con
`supabase db push` ni con `supabase db reset`.

## ¿Por qué está separada de `migrations/`?

| `migrations/`                          | `queries/`                          |
|----------------------------------------|-------------------------------------|
| Historial del esquema de la BD         | Consultas que se ejecutan a mano    |
| Inmutables y secuenciales (timestamp)  | Editables y reutilizables           |
| Las aplica el CLI, en orden            | El CLI las ignora                   |

## Estructura

- `reportes/` — consultas para informes y métricas de negocio.
- `analisis/` — consultas ad-hoc de exploración y análisis de datos (ej. `monitor_reversiones.sql`).
- `mantenimiento/` — limpieza, backfills, verificaciones y tareas operativas.
- `Seeds/` — fixtures de datos **por entorno**, corridos a mano (ej. `seed_staging.sql`). **No** son migraciones ni se aplican con el CLI.

## ⚠️ No confundir los dos "seeds"

| Archivo | Qué es | Quién lo aplica |
|---------|--------|-----------------|
| `supabase/seed.sql` (raíz) | Catálogos **globales** de referencia (bancos, `tax_rates`, `plan_catalog`, `dte_types`, etc.) | **El CLI**, automático (`db reset` / creación de branch) |
| `supabase/queries/Seeds/seed_staging.sql` | Fixture de datos de **negocio de Staging** (mundos GoT/LOTR + membresías de los dueños) | **A mano**, en el SQL Editor de la branch de Staging |

El seed de Staging trae **barrera anti-producción** (aborta si detecta la organización real) y **jamás** debe aplicarse a producción ni por el CLI.

## Convención de nombres

Usa nombres descriptivos en `snake_case`, sin timestamp:

```
reportes/colaboradores_por_proyecto.sql
mantenimiento/verificar_permisos_huerfanos.sql
```

Encabeza cada archivo con un comentario que explique qué hace y cómo usarlo:

```sql
-- Colaboradores activos agrupados por proyecto.
-- Uso: ejecutar en el SQL Editor o con `supabase db query`.
```
