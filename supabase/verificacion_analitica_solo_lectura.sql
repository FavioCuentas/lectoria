-- =============================================================
-- VERIFICACIÓN DE ANALÍTICA — CONSULTAS DE SOLO LECTURA
-- Ejecutar en Supabase SQL Editor (proyecto qikgjqbqjlgoeuxtujiy)
-- Ninguna consulta modifica datos, tablas, RLS ni funciones.
-- =============================================================

-- PASO A: Introspección — confirmar columnas reales de analytics_events
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'analytics_events'
ORDER BY ordinal_position;

-- PASO B: Introspección — ¿existe la RPC ingest_analytics_event?
-- (el cliente iOS actual NO la usa; inserta directo en /rest/v1/analytics_events)
SELECT routine_name, routine_type, data_type AS return_type
FROM information_schema.routines
WHERE routine_schema = 'public' AND routine_name ILIKE '%analytics%';

-- PASO C: Introspección — políticas RLS vigentes sobre la tabla
SELECT polname AS policy_name, polcmd AS command, polroles::regrole[] AS roles
FROM pg_policy
WHERE polrelid = 'public.analytics_events'::regclass;

-- PASO D: Correlación — eventos recibidos en la última hora
-- Ejecutar DESPUÉS de la prueba en el iPhone. Ajustar el intervalo si hace falta.
SELECT id, event_name, installation_id, session_id,
       properties, app_version, device_family,
       client_timestamp, created_at
FROM public.analytics_events
WHERE created_at >= now() - interval '1 hour'
  AND event_name IN ('document_imported', 'reading_session_ended')
ORDER BY created_at DESC
LIMIT 50;

-- PASO E (opcional): correlacionar por installation_id concreto
-- Sustituir <INSTALLATION_ID> por el UUID mostrado en los logs de la app.
-- SELECT event_name, properties, client_timestamp, created_at
-- FROM public.analytics_events
-- WHERE installation_id = '<INSTALLATION_ID>'
-- ORDER BY created_at DESC
-- LIMIT 20;
