-- Gate B · Recortar privilegios no-DML de anon y authenticated en public.
--
-- Hallazgo (auditoría 2026-07-24): el GRANT ALL por defecto dejó a anon y a
-- authenticated con TRUNCATE, TRIGGER y REFERENCES sobre las ~79 tablas de
-- public. Ninguno de esos privilegios se usa desde la app (PostgREST no expone
-- TRUNCATE) pero TRUNCATE **no pasa por RLS**: si algún día existe un camino de
-- SQL directo con esos roles, un TRUNCATE vaciaría una tabla completa ignorando
-- las políticas. Defensa en profundidad: se revocan los tres.
--
-- SELECT/INSERT/UPDATE/DELETE no se tocan (los gobierna la RLS).
--
-- Limitación conocida: no podemos cambiar los DEFAULT PRIVILEGES del rol que
-- otorga (limitación del rol postgres en Supabase, ya vista en la migración
-- 20260621140000), así que tablas creadas DESPUÉS de esta migración vuelven a
-- nacer con estos grants. Regla operativa: toda migración futura que haga
-- CREATE TABLE debe cerrar con el mismo REVOKE para sus tablas nuevas.
--
-- No-op seguro de re-ejecutar; verificado en staging (2026-07-24).

REVOKE TRUNCATE, TRIGGER, REFERENCES ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON ALL TABLES IN SCHEMA public FROM authenticated;
