-- ---------------------------------------------------------------------------
-- Keep-alive: scripts/keepalive.py inserts a row on a schedule so the free
-- project sees database activity and is not paused. Newest 5 rows kept.
-- ---------------------------------------------------------------------------
CREATE TABLE public.alive (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  alive boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE public.alive IS 'Keep-alive pings (scripts/keepalive.py) so the free project is not paused. Max 5 rows; older rows deleted on insert.';

-- Deletes all but the newest 5 rows after each insert.
CREATE FUNCTION public.alive_trim() RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  DELETE FROM public.alive WHERE id NOT IN (SELECT id FROM public.alive ORDER BY id DESC LIMIT 5);
  RETURN NULL;
END $$;

CREATE TRIGGER alive_trim AFTER INSERT ON public.alive
  FOR EACH STATEMENT EXECUTE FUNCTION public.alive_trim();

-- After each keep-alive ping, a Sentry check-in for monitor supabase-keepalive (cron 0 1,3,5,7 * * *
-- America/Chicago); a failed or missing ping means no check-in, so Sentry alerts. Never fails the insert.
CREATE OR REPLACE FUNCTION public.report_keepalive()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  BEGIN
    PERFORM net.http_get(url := 'https://o4512428086001664.ingest.us.sentry.io/api/4512430998683648/cron/supabase-keepalive/45a69cd26302470c8f9d80cbcdca9c07/?status=ok');
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'report_keepalive failed: %', SQLERRM;
  END;
  RETURN NULL;
END;
$$;
COMMENT ON FUNCTION public.report_keepalive() IS 'Keep-alive trigger: Sentry check-in for monitor supabase-keepalive; a missed ping alerts. Never fails the insert.';

CREATE TRIGGER report_keepalive AFTER INSERT ON public.alive
  FOR EACH STATEMENT EXECUTE FUNCTION public.report_keepalive();
