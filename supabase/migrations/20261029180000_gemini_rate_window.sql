-- ---------------------------------------------------------------------------
-- gemini_requests: sliding window log of every Gemini call the homepage chat
-- makes (each model turn, not just each visitor message). The site has no
-- login, so all visitors share one window. Only the chat role can touch it.
--   log_gemini_request()  logs one call, drops expired rows, returns usage
--   get_gemini_usage()    { now, used: [{ id, sent_at, expires_at }] } for
--                         the calls still inside the 1-minute window
-- ---------------------------------------------------------------------------
CREATE TABLE public.gemini_requests (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sent_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX gemini_requests_sent_at_idx ON public.gemini_requests (sent_at);

ALTER TABLE public.gemini_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gemini_requests FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.gemini_requests FROM anon, authenticated;
GRANT SELECT, INSERT, DELETE ON TABLE public.gemini_requests TO chat;
CREATE POLICY chat_window ON public.gemini_requests FOR ALL TO chat USING (true) WITH CHECK (true);

CREATE FUNCTION public.get_gemini_usage()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'now', now(),
    'used', coalesce(
      jsonb_agg(
        jsonb_build_object('id', id, 'sent_at', sent_at, 'expires_at', sent_at + interval '1 minute')
        ORDER BY sent_at
      ),
      '[]'::jsonb
    )
  )
  FROM public.gemini_requests
  WHERE sent_at > now() - interval '1 minute';
$$;

CREATE FUNCTION public.log_gemini_request()
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  DELETE FROM public.gemini_requests WHERE sent_at <= now() - interval '1 minute';
  INSERT INTO public.gemini_requests DEFAULT VALUES;
  RETURN public.get_gemini_usage();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_gemini_usage() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.log_gemini_request() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_gemini_usage() TO chat;
GRANT EXECUTE ON FUNCTION public.log_gemini_request() TO chat;
