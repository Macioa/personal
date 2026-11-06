-- ---------------------------------------------------------------------------
-- gemini_requests: sliding window log of every Gemini call the homepage chat
-- makes (each model turn, not just each visitor message). The site has no
-- login, so all visitors share one window. The chat role reads it and writes
-- only through log_gemini_request (SECURITY DEFINER), so it can't reset it.
--   log_gemini_request()  logs one call, drops expired rows, returns usage
--   get_gemini_usage()    { now, used: [{ id, sent_at, expires_at }] } for
--                         the calls still inside the 1-minute window
-- ---------------------------------------------------------------------------
CREATE TABLE public.gemini_requests (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sent_at timestamptz NOT NULL DEFAULT now()
);

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
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  DELETE FROM public.gemini_requests WHERE sent_at <= now() - interval '1 minute';
  INSERT INTO public.gemini_requests DEFAULT VALUES;
  RETURN public.get_gemini_usage();
END;
$$;

-- ---------------------------------------------------------------------------
-- faq: frequently asked questions for the homepage chat. chat reads only.
--   get_faq(slug)      { question, answer } or null
--   get_faqs(slugs)    [{ slug, question, answer }] in slug order given
--   get_all_faqs()     [{ slug, question }]
-- ---------------------------------------------------------------------------
CREATE TABLE public.faq (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  slug text NOT NULL UNIQUE,
  question text NOT NULL,
  answer text NOT NULL
);

CREATE FUNCTION public.get_faq(p_slug text)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT jsonb_build_object('question', question, 'answer', answer)
  FROM public.faq
  WHERE slug = p_slug;
$$;

CREATE FUNCTION public.get_faqs(p_slugs text[])
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object('slug', f.slug, 'question', f.question, 'answer', f.answer)
      ORDER BY s.ord
    ),
    '[]'::jsonb
  )
  FROM unnest(p_slugs) WITH ORDINALITY AS s(slug, ord)
  JOIN public.faq f ON f.slug = s.slug;
$$;

CREATE FUNCTION public.get_all_faqs()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT coalesce(
    jsonb_agg(jsonb_build_object('slug', slug, 'question', question) ORDER BY slug),
    '[]'::jsonb
  )
  FROM public.faq;
$$;

CREATE TABLE public.inbound_messages (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  message text NOT NULL CHECK (length(message) BETWEEN 1 AND 5000),
  "from" text CHECK (length("from") <= 320),
  date timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.inbound_messages IS
  'Homepage chat messages. Write: send_message. INSERT webhook emails via notify-inbound-message.';

-- Logs one chat message; blank from is stored as null.
CREATE FUNCTION public.send_message(message text, "from" text DEFAULT NULL)
RETURNS void
LANGUAGE sql VOLATILE SET search_path = '' AS $$
  INSERT INTO public.inbound_messages (message, "from")
  VALUES (send_message.message, nullif(trim(send_message."from"), ''))
$$;
COMMENT ON FUNCTION public.send_message(text, text) IS 'Log a chat message. from optional.';
