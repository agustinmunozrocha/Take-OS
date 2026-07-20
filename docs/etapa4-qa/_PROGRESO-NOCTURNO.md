# Progreso corrida nocturna — QA módulos con catálogo

**Inicio:** 2026-07-20 (sesión Chrome MCP, modo liviano)
**Rama:** etapa4-integracion · **Login:** perfil@administrador.com

## Orden y estado
| # | Módulo | Pruebas | Estado |
|---|--------|---------|--------|
| 1 | Cargos | 17 | ✅ 15/17 · 0 bugs (CG16 incompleto·tope, CG17 pendiente·permiso) |
| 2 | Crew | 18 | ✅ 8/18 · 0 bugs (5 pend·espejo presupuesto, 2 incompl·proyecto vacío, 3 👁 PDF) |
| 3 | Rodajes | 22 | 🔄 en curso |
| 4 | Documentos | 20 | ⬜ pendiente |
| 5 | Base de datos | 34 | ⬜ pendiente |

## Reglas de esta corrida
- Solo corro las 🤖 (técnicas); las 👁 (PDF/visual) van al reporte final para Agustín.
- Bug real → ❌ en catálogo + reproducción; NO se arregla.
- Nada de push/merge/migraciones. Commit local del registro por módulo.
- Hard refresh en toda prueba de guardar/editar/borrar.

## Bitácora
- Preparación OK: caffeinate, dev server 200, guard de impresión, login administrador.
- **Cargos (2026-07-20):** 15/17 ✅, 0 bugs. Persistencia CG13 confirmada por consulta
  a la base (project_cargos) + hard refresh. Proyecto de prueba P-1784507176223
  ("QA Plan de Rodaje") quedó limpio (0 cargos). Residuo menor: infoProyecto.director/PE
  quedaron con "Juan de la Cuadra" (la derivación no borra el valor previo al quitar el
  cargo, por diseño). CG16 incompleto (requiere 12 colaboradores). CG17 pendiente
  (login con otro perfil, va a la pasada de permisos junto con los demás módulos).
