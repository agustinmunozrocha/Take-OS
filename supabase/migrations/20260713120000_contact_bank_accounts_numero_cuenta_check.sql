-- Validación de numero_cuenta en contact_bank_accounts.
--
-- Motivo: hoy cualquier string entra como número de cuenta (se vio un valor de
-- 23 dígitos y otro que era "777" + el RUT de la persona). Esos valores van
-- directo al archivo de transferencias masivas del banco → rechazo o, peor,
-- plata a la cuenta equivocada.
--
-- Regla: para cuentas NACIONALES el número debe ser solo dígitos, de 5 a 20 de
-- largo. Las EXTRANJERAS (es_extranjera = true) quedan libres porque pueden ser
-- IBAN alfanumérico. NULL permitido (cuenta sin número aún).
--
-- Cotas 5–20 confirmadas por Agustín y contra los datos reales de producción:
--   · mínimo observado = 7 dígitos (cuentas 9831172 / 8716006) → el 8 que
--     sugería el handoff habría rechazado cuentas válidas; se baja a 5.
--   · ningún valor > 20 tras la limpieza previa → el tope 20 atrapa la clase
--     "23 dígitos" sin falsos positivos. 0 filas violadoras (verificado en prod
--     por transacción revertida el 2026-07-13).
--
-- Limitación conocida: NO detecta un número bien formado pero inventado
-- (ej. 777021177913, que pasa por largo). Eso requeriría validación por banco
-- (bank_codigo_sbif) — queda como deuda ("validación de cuentas por tipo").
--
-- Interacción con el trigger fn_norm_bank_accounts: ese trigger BEFORE ya deja
-- las nacionales en solo dígitos, así que el CHECK evalúa el valor normalizado.

ALTER TABLE public.contact_bank_accounts
  ADD CONSTRAINT chk_numero_cuenta_formato
  CHECK (
    es_extranjera
    OR numero_cuenta IS NULL
    OR numero_cuenta ~ '^[0-9]{5,20}$'
  );
