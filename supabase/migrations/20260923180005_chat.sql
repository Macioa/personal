-- ---------------------------------------------------------------------------
-- chat: login role for a career chat. Only the career functions plus the
-- tables they read (functions are SECURITY INVOKER), with resume_reader's
-- non-private row filters. Set its password out of band:
--   ALTER ROLE chat PASSWORD '...';
-- ---------------------------------------------------------------------------
CREATE ROLE chat LOGIN NOINHERIT;
-- Lets PostgREST switch to chat for get-llm-token JWTs.
GRANT chat TO authenticator;

GRANT USAGE ON SCHEMA public TO chat;
GRANT EXECUTE ON FUNCTION public.get_skill(text, public.skill_usage_mode) TO chat;
GRANT EXECUTE ON FUNCTION public.get_skills(text[], public.skill_usage_mode) TO chat;
GRANT EXECUTE ON FUNCTION public.pitch_detail(text[], public.skill_usage_mode) TO chat;

GRANT SELECT ON TABLE public.employer TO chat;
GRANT SELECT ON TABLE public.employment_titles TO chat;
GRANT SELECT ON TABLE public.education_and_training TO chat;
GRANT SELECT ON TABLE public.personal_growth TO chat;
GRANT SELECT ON TABLE public.skills TO chat;
GRANT SELECT ON TABLE public.skill_links TO chat;
GRANT SELECT ON TABLE public.pitches TO chat;
GRANT SELECT ON TABLE public.pitch_skills TO chat;
GRANT SELECT ON TABLE public.pitch_evidence TO chat;
GRANT SELECT ON TABLE public.pitch_catalog TO chat;

-- Share resume_reader's private-row filters.
ALTER POLICY resume_reader_select ON public.employer TO resume_reader, chat;
ALTER POLICY resume_reader_select ON public.employment_titles TO resume_reader, chat;
ALTER POLICY resume_reader_select ON public.education_and_training TO resume_reader, chat;
ALTER POLICY resume_reader_select ON public.personal_growth TO resume_reader, chat;
ALTER POLICY resume_reader_select ON public.skills TO resume_reader, chat;
ALTER POLICY resume_reader_select ON public.skill_links TO resume_reader, chat;
ALTER POLICY resume_reader_select ON public.pitches TO resume_reader, chat;
ALTER POLICY resume_reader_select ON public.pitch_skills TO resume_reader, chat;
ALTER POLICY resume_reader_select ON public.pitch_evidence TO resume_reader, chat;
