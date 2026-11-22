-- Consulta pública y mínima de convenio por dominio (antes de iniciar sesión).
-- institution_domains solo es legible por usuarios autenticados, así que la app no podía
-- comprobar el dominio como invitado y siempre respondía "sin convenio".
-- Esta función solo revela si UN dominio dado tiene convenio activo y el nombre de la institución.

CREATE OR REPLACE FUNCTION public.lookup_institution_by_domain(p_domain TEXT)
RETURNS TABLE (id UUID, name TEXT, slug TEXT, plan_type TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT i.id, i.name, i.slug, i.plan_type
    FROM public.institution_domains d
    JOIN public.institutions i ON i.id = d.institution_id
    WHERE d.domain = lower(trim(p_domain))
      AND d.is_active = true
      AND i.is_active = true
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.lookup_institution_by_domain(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_institution_by_domain(TEXT) TO anon, authenticated;
