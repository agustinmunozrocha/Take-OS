-- Seguridad basal (canonico 6.4): cerrar la invocacion publica de funciones internas.
-- Revoca EXECUTE a PUBLIC/anon/authenticated de:
--   (a) funciones de trigger  (las dispara el sistema, no se llaman directo)
--   (b) funciones auxiliares internas (prefijo '_', las llaman las RPC SECURITY DEFINER)
-- El dueno (postgres) conserva el permiso, la cadena SECURITY DEFINER sigue intacta.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (p.prorettype = 'pg_catalog.trigger'::regtype OR p.proname LIKE '\_%')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated;', r.sig);
  END LOOP;
END $$;
