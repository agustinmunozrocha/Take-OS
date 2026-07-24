-- Gate B · Capturar en migración las políticas de Storage creadas a mano.
--
-- Contexto: las políticas de storage.objects (org-scoped por primer segmento
-- del path) se crearon por dashboard y NUNCA quedaron en una migración; un
-- rebuild fresco tenía buckets sin políticas (o políticas sin buckets, como le
-- pasó a staging hasta el 14-jul). Esta migración las captura como fuente de
-- verdad reproducible, junto con sus dos funciones helper.
--
-- Idempotente y no-op donde ya existen (prod y staging las tienen): cada
-- política se crea SOLO si no existe, para no depender de permisos de DROP
-- sobre storage.objects. Los helpers usan CREATE OR REPLACE (schema public,
-- somos dueños).
--
-- Modelo: buckets privados; el path es <organization_id>/<...>. El acceso
-- exige membresía activa en esa organización (auth_es_miembro_org_txt); el
-- bucket documentos-legales exige además el módulo gastos_legal_notificaciones
-- (L para leer, E para escribir). herramientas-personales es por usuario
-- (primer segmento = auth.uid()); sus políticas hp_* también se capturan.

CREATE OR REPLACE FUNCTION public.auth_es_miembro_org_txt(p_org_text text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM memberships m
    WHERE m.user_id = auth.uid()
      AND m.estado = 'activo'
      AND m.organization_id::text = p_org_text
  );
$$;

CREATE OR REPLACE FUNCTION public.auth_nivel_org_txt(p_modulo text, p_org_text text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  -- COALESCE(..., 'none'): mismo contrato que auth_nivel (NUNCA devuelve NULL).
  -- Sin esto, usada con negación (nivel <> 'E') daría NULL → el IF no dispara →
  -- fail-open silencioso. (Fix bloqueante · BD Expert, 24-jul-2026.)
  -- Se compara la org por TEXTO a propósito: el primer segmento del path de
  -- Storage puede no ser un uuid válido; castear a uuid lanzaría excepción en
  -- vez de denegar.
  SELECT COALESCE(
    (SELECT pp.nivel
     FROM memberships m
     JOIN profile_permissions pp ON pp.profile_id = m.profile_id
     WHERE m.user_id = auth.uid()
       AND m.estado = 'activo'
       AND m.organization_id::text = p_org_text
       AND pp.modulo = p_modulo
     LIMIT 1),
    'none');
$$;

DO $$
DECLARE
  v_org_buckets text := $b$ARRAY['fotos-locaciones','adjuntos-tareas','documentos-proyecto','adjuntos-gastos','cotizaciones','fotos-plan-de-rodaje-y-guion-tecnico','fotos-talentos','hojas-llamado']$b$;
  v_miembro text := 'auth_es_miembro_org_txt((storage.foldername(name))[1])';
  v_legal_e text := $e$auth_nivel_org_txt('gastos_legal_notificaciones', (storage.foldername(name))[1]) = 'E'$e$;
  v_legal_l text := $l$auth_nivel_org_txt('gastos_legal_notificaciones', (storage.foldername(name))[1]) IN ('E','L')$l$;
  v_hp text := $h$bucket_id = 'herramientas-personales' AND (storage.foldername(name))[1] = auth.uid()::text$h$;
  v_org_expr text;
BEGIN
  -- Expresión org-scoped común (buckets de organización + caso legal)
  v_org_expr := '(bucket_id = ANY (' || v_org_buckets || ') AND ' || v_miembro || ')';

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='takeos_storage_select') THEN
    EXECUTE 'CREATE POLICY takeos_storage_select ON storage.objects FOR SELECT TO authenticated USING ('
      || v_org_expr || ' OR (bucket_id = ''documentos-legales'' AND ' || v_legal_l || '))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='takeos_storage_insert') THEN
    EXECUTE 'CREATE POLICY takeos_storage_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK ('
      || v_org_expr || ' OR (bucket_id = ''documentos-legales'' AND ' || v_legal_e || '))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='takeos_storage_update') THEN
    EXECUTE 'CREATE POLICY takeos_storage_update ON storage.objects FOR UPDATE TO authenticated USING ('
      || v_org_expr || ' OR (bucket_id = ''documentos-legales'' AND ' || v_legal_e || '))'
      || ' WITH CHECK (' || v_org_expr || ' OR (bucket_id = ''documentos-legales'' AND ' || v_legal_e || '))';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='takeos_storage_delete') THEN
    EXECUTE 'CREATE POLICY takeos_storage_delete ON storage.objects FOR DELETE TO authenticated USING ('
      || v_org_expr || ' OR (bucket_id = ''documentos-legales'' AND ' || v_legal_e || '))';
  END IF;

  -- herramientas-personales (por usuario)
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='hp_select') THEN
    EXECUTE 'CREATE POLICY hp_select ON storage.objects FOR SELECT TO authenticated USING (' || v_hp || ')';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='hp_insert') THEN
    EXECUTE 'CREATE POLICY hp_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (' || v_hp || ')';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='hp_update') THEN
    EXECUTE 'CREATE POLICY hp_update ON storage.objects FOR UPDATE TO authenticated USING (' || v_hp || ') WITH CHECK (' || v_hp || ')';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='hp_delete') THEN
    EXECUTE 'CREATE POLICY hp_delete ON storage.objects FOR DELETE TO authenticated USING (' || v_hp || ')';
  END IF;
END $$;
