-- Unicidad de RUT normalizado por organización (anti-duplicados).
--
-- Motivo: se encontraron dos contactos de la misma persona (mismo email), uno
-- con RUT y otro con RUT NULL. El cruce con Chipax se hace POR RUT, así que el
-- duplicado sin RUT es invisible para pagos: el usuario edita un registro que
-- el proceso de pagos nunca lee.
--
-- Ya existe contacts_rut_unico_por_org UNIQUE (organization_id, rut), pero:
--   · no normaliza (21.177.913-6 vs 21177913-6 se consideran distintos), y
--   · admite múltiples filas con rut = NULL (NULL no colisiona en UNIQUE).
--
-- Este índice complementa: normaliza a dígitos + K (minúscula), es por org, y
-- excluye NULL y borrados. No reemplaza al constraint viejo; convive con él.
--
-- Verificado contra producción (transacción revertida, 2026-07-13): 0 duplicados
-- por RUT normalizado entre contactos activos → el índice se crea limpio.
--
-- La expresión regexp_replace(lower(rut), ...) es IMMUTABLE, requisito para un
-- índice funcional.

CREATE UNIQUE INDEX IF NOT EXISTS uniq_contacts_rut_norm_por_org
  ON public.contacts (organization_id, regexp_replace(lower(rut), '[^0-9k]', '', 'g'))
  WHERE rut IS NOT NULL AND deleted_at IS NULL;
