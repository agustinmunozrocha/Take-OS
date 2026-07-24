-- Ajuste de permisos del módulo 'bd' (base de contactos) por perfil.
--
-- Decisión de Agustín (2026-07-13): editan la base de contactos los perfiles
-- Administrador, Ejecutivo, Producción, Finanzas y Asistencia; el resto no edita.
-- Respecto del estado actual, esto implica solo DOS cambios de nivel:
--   · Finanzas (profile_id 8): L (lector) → E (editor). Maneja cuentas, debe editar.
--   · Coordinación (profile_id 5): E (editor) → L (lector). No debe editar la base.
--
-- Los demás perfiles ya están en su nivel objetivo y no se tocan:
--   Administrador(1)=E, Ejecutivo(2)=E, Producción(3)=E, Asistencia(4)=E,
--   Creativo(6)=L, Invitado(7)=none.
--
-- Nota: se deja a Coordinación y Creativo en 'L' (no 'none') a propósito: con 'L'
-- pueden LEER contactos, lo que mantiene poblados los comboboxes de toda la app
-- (elegir personas en presupuesto, gastos, cargos, etc.). Que no vean la PANTALLA
-- de la base de contactos se resuelve en el frontend (esconder el módulo BD a los
-- lectores), no en la RLS. profile_permissions es global por perfil (sin org).
--
-- Verificado contra producción (transacción revertida, 2026-07-13): tras el
-- cambio, Finanzas queda en 'E' y Coordinación en 'L', sin error.

UPDATE public.profile_permissions SET nivel = 'E' WHERE profile_id = 8 AND modulo = 'bd';  -- Finanzas
UPDATE public.profile_permissions SET nivel = 'L' WHERE profile_id = 5 AND modulo = 'bd';  -- Coordinación
