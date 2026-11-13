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
