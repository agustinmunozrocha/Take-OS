-- monitor_reversiones.sql
-- =============================================================================
-- Monitor de reversiones de datos en Producción
-- (sobrescritura de estado completo sin control de concurrencia)
-- =============================================================================
-- QUÉ DETECTA
--   Escrituras posteriores que reproducen una FILA VIEJA COMPLETA (todos los
--   campos menos updated_at) sobre una versión más nueva. Es la firma del
--   guardado de "estado completo" sin control de concurrencia de las RPC
--   guardar_proyecto / guardar_operaciones_* (ver Handoff BD Expert → Dev/Code,
--   21-jun-2026). Cada coincidencia = un cambio que probablemente se perdió.
--
-- CÓMO SE USA
--   Consulta de ANÁLISIS, SOLO LECTURA. Se corre A MANO contra PRODUCCIÓN
--   cuando se quiere una lectura. No es migración ni job programado: por eso
--   vive en queries/analisis/, no en migrations/. Ventana configurable: cambiar
--   el interval '40 days'.
--
-- LÍNEA BASE (21-jun-2026)
--   Última reversión conocida: 11-jun 13:37 (projects / P-1780327236865).
--   Registros afectados a la fecha: projects/P-1780327236865 y contacts/ctk_60cff01aef.
--   → Cualquier reversión POSTERIOR al 11-jun 13:37, o un registro nuevo en la
--     lista, es un GOLPE NUEVO (el bug volvió a pegar).
-- =============================================================================

-- (A) RESUMEN — un renglón por registro afectado, con conteo y última reversión
WITH ev AS (
  SELECT tabla, registro_id, created_at, actor_uid,
         (cambios->'new') - 'updated_at' AS snap_new,
         (cambios->'old') - 'updated_at' AS snap_old
  FROM audit_log
  WHERE accion = 'UPDATE' AND cambios ? 'new' AND cambios ? 'old'
    AND created_at > now() - interval '40 days'
),
rev AS (
  SELECT e2.tabla, e2.registro_id, e2.created_at AS t_revert, e2.actor_uid
  FROM ev e2
  WHERE EXISTS (
    SELECT 1 FROM ev e1
    WHERE e1.tabla = e2.tabla AND e1.registro_id = e2.registro_id
      AND e1.created_at < e2.created_at
      AND e1.snap_old <> e1.snap_new        -- el primero fue un cambio real
      AND e2.snap_new = e1.snap_old          -- el segundo reescribió el estado viejo completo
  )
)
SELECT r.tabla,
       r.registro_id,
       count(*)        AS eventos_reversion,
       min(r.t_revert) AS primera_reversion,
       max(r.t_revert) AS ultima_reversion,
       max(u.email)    AS actor
FROM rev r
LEFT JOIN auth.users u ON u.id = r.actor_uid
GROUP BY r.tabla, r.registro_id
ORDER BY ultima_reversion DESC;

-- (B) DETALLE — un renglón por evento de reversión (descomentar para investigar un caso)
/*
WITH ev AS (
  SELECT tabla, registro_id, created_at, actor_uid,
         (cambios->'new') - 'updated_at' AS snap_new,
         (cambios->'old') - 'updated_at' AS snap_old
  FROM audit_log
  WHERE accion = 'UPDATE' AND cambios ? 'new' AND cambios ? 'old'
    AND created_at > now() - interval '40 days'
)
SELECT e2.tabla, e2.registro_id,
       e1.created_at AS t_estado_viejo,
       e2.created_at AS t_revirtio_a_viejo,
       round(extract(epoch FROM (e2.created_at - e1.created_at))/3600, 1) AS horas_entre,
       ua.email AS quien_revirtio
FROM ev e1
JOIN ev e2 ON e2.tabla = e1.tabla AND e2.registro_id = e1.registro_id AND e2.created_at > e1.created_at
LEFT JOIN auth.users ua ON ua.id = e2.actor_uid
WHERE e2.snap_new = e1.snap_old AND e1.snap_old <> e1.snap_new
ORDER BY e2.created_at DESC
LIMIT 50;
*/
