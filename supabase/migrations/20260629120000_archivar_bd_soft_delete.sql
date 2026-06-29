-- ============================================================================
-- Archivar (soft-delete) la Base de Datos · contactos, empresas y locaciones
-- ----------------------------------------------------------------------------
-- Pedido de Agustín: poder "eliminar" personas, empresas, talentos y locaciones,
-- SOLO con perfil Administrador. Implementado como SOFT-DELETE (archivar): marca
-- deleted_at, es recuperable y NO rompe referencias históricas (gastos, proyectos,
-- cargos). No hay purga automática: archivar != borrar definitivo.
--
-- Estado previo:
--   · contacts / companies: ya tienen deleted_at y su carga ya filtra
--     deleted_at IS NULL (index.html). Solo faltaba una vía admin-only de marcado.
--   · locations: NO tenía deleted_at -> se agrega aquí (aditivo).
--   · talentos = contacts (archivar el contacto los cubre).
--
-- Permiso server-side (doctrina ADR "permisos sensibles = RPC"). Cada RPC es
-- SECURITY DEFINER y exige Administrador (auth_codigo_perfil(org) = 1), espejo de
-- las políticas b_contacts_del / b_companies_del (FOR DELETE ... = 1). El frontend
-- (fase aparte) solo llama estos RPC desde botones gateados a admin.
-- IDs: contacts.id y companies.id son TEXT (ctk_/emp_); locations.loc_id es TEXT.
-- ============================================================================

-- 1) locations: columna deleted_at (aditiva) ---------------------------------
ALTER TABLE public.locations
  ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;

-- 2) RPCs archivar / restaurar (admin-only) ----------------------------------

-- contactos (cubre personas y talentos) --------------------------------------
CREATE OR REPLACE FUNCTION public.archivar_contacto(p_id text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_org uuid;
BEGIN
  IF p_id IS NULL OR p_id = '' THEN RAISE EXCEPTION 'archivar_contacto: falta id'; END IF;
  SELECT organization_id INTO v_org FROM contacts WHERE id = p_id;
  IF v_org IS NULL THEN RAISE EXCEPTION 'archivar_contacto: contacto % no existe', p_id; END IF;
  IF coalesce(auth_codigo_perfil(v_org), 0) <> 1 THEN RAISE EXCEPTION 'archivar_contacto: solo Administrador'; END IF;
  UPDATE contacts SET deleted_at = now(), updated_at = now() WHERE id = p_id AND deleted_at IS NULL;
  RETURN p_id;
END; $$;
ALTER FUNCTION public.archivar_contacto(text) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.restaurar_contacto(p_id text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_org uuid;
BEGIN
  IF p_id IS NULL OR p_id = '' THEN RAISE EXCEPTION 'restaurar_contacto: falta id'; END IF;
  SELECT organization_id INTO v_org FROM contacts WHERE id = p_id;
  IF v_org IS NULL THEN RAISE EXCEPTION 'restaurar_contacto: contacto % no existe', p_id; END IF;
  IF coalesce(auth_codigo_perfil(v_org), 0) <> 1 THEN RAISE EXCEPTION 'restaurar_contacto: solo Administrador'; END IF;
  UPDATE contacts SET deleted_at = NULL, updated_at = now() WHERE id = p_id;
  RETURN p_id;
END; $$;
ALTER FUNCTION public.restaurar_contacto(text) OWNER TO postgres;

-- empresas -------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.archivar_empresa(p_id text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_org uuid;
BEGIN
  IF p_id IS NULL OR p_id = '' THEN RAISE EXCEPTION 'archivar_empresa: falta id'; END IF;
  SELECT organization_id INTO v_org FROM companies WHERE id = p_id;
  IF v_org IS NULL THEN RAISE EXCEPTION 'archivar_empresa: empresa % no existe', p_id; END IF;
  IF coalesce(auth_codigo_perfil(v_org), 0) <> 1 THEN RAISE EXCEPTION 'archivar_empresa: solo Administrador'; END IF;
  UPDATE companies SET deleted_at = now(), updated_at = now() WHERE id = p_id AND deleted_at IS NULL;
  RETURN p_id;
END; $$;
ALTER FUNCTION public.archivar_empresa(text) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.restaurar_empresa(p_id text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_org uuid;
BEGIN
  IF p_id IS NULL OR p_id = '' THEN RAISE EXCEPTION 'restaurar_empresa: falta id'; END IF;
  SELECT organization_id INTO v_org FROM companies WHERE id = p_id;
  IF v_org IS NULL THEN RAISE EXCEPTION 'restaurar_empresa: empresa % no existe', p_id; END IF;
  IF coalesce(auth_codigo_perfil(v_org), 0) <> 1 THEN RAISE EXCEPTION 'restaurar_empresa: solo Administrador'; END IF;
  UPDATE companies SET deleted_at = NULL, updated_at = now() WHERE id = p_id;
  RETURN p_id;
END; $$;
ALTER FUNCTION public.restaurar_empresa(text) OWNER TO postgres;

-- locaciones (PK loc_id text) ------------------------------------------------
CREATE OR REPLACE FUNCTION public.archivar_locacion(p_loc_id text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_org uuid;
BEGIN
  IF p_loc_id IS NULL OR p_loc_id = '' THEN RAISE EXCEPTION 'archivar_locacion: falta loc_id'; END IF;
  SELECT organization_id INTO v_org FROM locations WHERE loc_id = p_loc_id;
  IF v_org IS NULL THEN RAISE EXCEPTION 'archivar_locacion: locacion % no existe', p_loc_id; END IF;
  IF coalesce(auth_codigo_perfil(v_org), 0) <> 1 THEN RAISE EXCEPTION 'archivar_locacion: solo Administrador'; END IF;
  UPDATE locations SET deleted_at = now(), updated_at = now() WHERE loc_id = p_loc_id AND deleted_at IS NULL;
  RETURN p_loc_id;
END; $$;
ALTER FUNCTION public.archivar_locacion(text) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.restaurar_locacion(p_loc_id text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_org uuid;
BEGIN
  IF p_loc_id IS NULL OR p_loc_id = '' THEN RAISE EXCEPTION 'restaurar_locacion: falta loc_id'; END IF;
  SELECT organization_id INTO v_org FROM locations WHERE loc_id = p_loc_id;
  IF v_org IS NULL THEN RAISE EXCEPTION 'restaurar_locacion: locacion % no existe', p_loc_id; END IF;
  IF coalesce(auth_codigo_perfil(v_org), 0) <> 1 THEN RAISE EXCEPTION 'restaurar_locacion: solo Administrador'; END IF;
  UPDATE locations SET deleted_at = NULL, updated_at = now() WHERE loc_id = p_loc_id;
  RETURN p_loc_id;
END; $$;
ALTER FUNCTION public.restaurar_locacion(text) OWNER TO postgres;

-- 3) Permisos: revocar a public/anon, conceder solo a authenticated -----------
REVOKE ALL ON FUNCTION public.archivar_contacto(text)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.restaurar_contacto(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.archivar_empresa(text)   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.restaurar_empresa(text)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.archivar_locacion(text)  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.restaurar_locacion(text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.archivar_contacto(text)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.restaurar_contacto(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archivar_empresa(text)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.restaurar_empresa(text)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.archivar_locacion(text)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.restaurar_locacion(text) TO authenticated;
