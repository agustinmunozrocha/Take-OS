-- Gate B · Cerrar el hueco P1 del soft-delete de proyectos (server-side).
--
-- Problema: eliminar/restaurar un proyecto es un UPDATE de projects.deleted_at.
-- La política b_projects_upd solo exige info_proyecto='E', así que un perfil
-- Ejecutivo (info=E, eliminar_proyecto=none) puede fabricar la request y borrar
-- (u ocultar) proyectos aunque la UI se lo esconda. El chequeo real vivía solo
-- en el cliente (authNivel('eliminar_proyecto')==='E') y en la RPC
-- eliminar_proyecto — pero el UPDATE directo la eludía.
--
-- Fix: trigger BEFORE UPDATE que exige el módulo 'eliminar_proyecto' en 'E'
-- cuando el UPDATE toca deleted_at. Deja pasar a service_role/postgres (jobs,
-- RPCs SECURITY DEFINER del sistema, cron de eliminaciones definitivas).
--
-- Deploy-safe: el frontend actual (monolito y modular) hace el UPDATE directo
-- como Administrador (único perfil con el botón visible), que SÍ tiene
-- eliminar_proyecto='E' → su flujo sigue funcionando sin tocar el frontend.
-- Solo se bloquea la request fabricada por perfiles sin el permiso.
--
-- Verificado en staging (2026-07-24): ejecutivo → excepción; administrador →
-- borra y restaura OK; RPC eliminar_proyecto → OK.

CREATE OR REPLACE FUNCTION public.guard_projects_soft_delete()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  -- El trigger ya solo dispara cuando deleted_at cambia (cláusula WHEN de abajo),
  -- así que aquí no hace falta re-chequearlo.
  -- Roles de sistema (jobs, RPCs definer, cron) pasan directo.
  IF current_user IN ('postgres', 'service_role', 'supabase_admin') THEN
    RETURN NEW;
  END IF;
  IF auth_nivel('eliminar_proyecto', OLD.organization_id) <> 'E' THEN
    RAISE EXCEPTION 'takeos_auth: eliminar o restaurar proyectos es facultad del Administrador (módulo eliminar_proyecto).';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_projects_soft_delete ON public.projects;
-- WHEN: el guard solo corre cuando el UPDATE cambia deleted_at (no en cada save
-- de projects, que es camino caliente). IS DISTINCT FROM maneja NULLs (borrar =
-- NULL→ts, restaurar = ts→NULL). (Sugerencia BD Expert, 24-jul-2026.)
CREATE TRIGGER trg_guard_projects_soft_delete
  BEFORE UPDATE ON public.projects
  FOR EACH ROW
  WHEN (NEW.deleted_at IS DISTINCT FROM OLD.deleted_at)
  EXECUTE FUNCTION public.guard_projects_soft_delete();
