-- MCP-only access: enable RLS with no anon/authenticated policies.
-- service_role (and MCP SQL) bypasses RLS; Data API clients stay locked out.

ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_interviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_info_and_docs ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.applications FORCE ROW LEVEL SECURITY;
ALTER TABLE public.application_interviews FORCE ROW LEVEL SECURITY;
ALTER TABLE public.application_conversations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.personal_info_and_docs FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.applications FROM anon, authenticated;
REVOKE ALL ON TABLE public.application_interviews FROM anon, authenticated;
REVOKE ALL ON TABLE public.application_conversations FROM anon, authenticated;
REVOKE ALL ON TABLE public.personal_info_and_docs FROM anon, authenticated;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
