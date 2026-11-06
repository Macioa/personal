-- DB config only: account-specific values, then RLS, grants, revokes, roles and
-- policies for tables defined in earlier migrations. No tables or data.
--
-- ACCOUNT-SPECIFIC: the values below intentionally differ from live. Git keeps
-- placeholders only; replace them per database before applying.

-- ---------------------------------------------------------------------------
-- Account-specific values
-- ---------------------------------------------------------------------------
ALTER TABLE public.applications
  ADD COLUMN which_personal_email_used public.personal_email_used;

-- Replace this placeholder with your auth.users ID before applying.
ALTER TABLE public.applications
  ALTER COLUMN user_id SET DEFAULT '00000000-0000-0000-0000-000000000000'::uuid;

-- Replace this placeholder with your auth.users ID before applying.
ALTER TABLE public.personal_info_and_docs
  ALTER COLUMN user_id SET DEFAULT '00000000-0000-0000-0000-000000000000'::uuid;

-- ---------------------------------------------------------------------------
-- MCP-only access: RLS on, no anon/authenticated policies or grants
-- ---------------------------------------------------------------------------
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_interviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.todolist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_info_and_docs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_logins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.abuse ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.abuse_impact_rubric ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.abuse_severity_rubric ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.abuse_impact_escalator ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.abuse_severity_escalator ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employer ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employment_titles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employer_portals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.education_and_training ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_growth ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employer_employer_portals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skill_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pitches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pitch_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pitch_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_growth ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inbound_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.faq ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gemini_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backup_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backup_transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transcript_speakers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transcript_turns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transcript_chunks ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.applications FORCE ROW LEVEL SECURITY;
ALTER TABLE public.application_interviews FORCE ROW LEVEL SECURITY;
ALTER TABLE public.application_conversations FORCE ROW LEVEL SECURITY;
ALTER TABLE public.todolist FORCE ROW LEVEL SECURITY;
ALTER TABLE public.personal_info_and_docs FORCE ROW LEVEL SECURITY;
ALTER TABLE public.logins FORCE ROW LEVEL SECURITY;
ALTER TABLE public.application_logins FORCE ROW LEVEL SECURITY;
ALTER TABLE public.abuse FORCE ROW LEVEL SECURITY;
ALTER TABLE public.abuse_impact_rubric FORCE ROW LEVEL SECURITY;
ALTER TABLE public.abuse_severity_rubric FORCE ROW LEVEL SECURITY;
ALTER TABLE public.abuse_impact_escalator FORCE ROW LEVEL SECURITY;
ALTER TABLE public.abuse_severity_escalator FORCE ROW LEVEL SECURITY;
ALTER TABLE public.employer FORCE ROW LEVEL SECURITY;
ALTER TABLE public.employment_titles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.employer_portals FORCE ROW LEVEL SECURITY;
ALTER TABLE public.skills FORCE ROW LEVEL SECURITY;
ALTER TABLE public.education_and_training FORCE ROW LEVEL SECURITY;
ALTER TABLE public.personal_growth FORCE ROW LEVEL SECURITY;
ALTER TABLE public.employer_employer_portals FORCE ROW LEVEL SECURITY;
ALTER TABLE public.skill_links FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pitches FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pitch_skills FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pitch_evidence FORCE ROW LEVEL SECURITY;
ALTER TABLE public.projects FORCE ROW LEVEL SECURITY;
ALTER TABLE public.project_skills FORCE ROW LEVEL SECURITY;
ALTER TABLE public.project_growth FORCE ROW LEVEL SECURITY;
ALTER TABLE public.inbound_messages FORCE ROW LEVEL SECURITY;
ALTER TABLE public.faq FORCE ROW LEVEL SECURITY;
ALTER TABLE public.gemini_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE public.backups FORCE ROW LEVEL SECURITY;
ALTER TABLE public.backup_sources FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transcripts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.backup_transcripts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transcript_speakers FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transcript_turns FORCE ROW LEVEL SECURITY;
ALTER TABLE public.transcript_chunks FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.applications FROM anon, authenticated;
REVOKE ALL ON TABLE public.application_interviews FROM anon, authenticated;
REVOKE ALL ON TABLE public.application_conversations FROM anon, authenticated;
REVOKE ALL ON TABLE public.todolist FROM anon, authenticated;
REVOKE ALL ON TABLE public.personal_info_and_docs FROM anon, authenticated;
REVOKE ALL ON TABLE public.logins FROM anon, authenticated;
REVOKE ALL ON TABLE public.application_logins FROM anon, authenticated;
REVOKE ALL ON TABLE public.abuse FROM anon, authenticated;
REVOKE ALL ON TABLE public.abuse_impact_rubric FROM anon, authenticated;
REVOKE ALL ON TABLE public.abuse_severity_rubric FROM anon, authenticated;
REVOKE ALL ON TABLE public.abuse_impact_escalator FROM anon, authenticated;
REVOKE ALL ON TABLE public.abuse_severity_escalator FROM anon, authenticated;
REVOKE ALL ON TABLE public.employer FROM anon, authenticated;
REVOKE ALL ON TABLE public.employment_titles FROM anon, authenticated;
REVOKE ALL ON TABLE public.employer_portals FROM anon, authenticated;
REVOKE ALL ON TABLE public.skills FROM anon, authenticated;
REVOKE ALL ON TABLE public.education_and_training FROM anon, authenticated;
REVOKE ALL ON TABLE public.personal_growth FROM anon, authenticated;
REVOKE ALL ON TABLE public.employer_employer_portals FROM anon, authenticated;
REVOKE ALL ON TABLE public.skill_links FROM anon, authenticated;
REVOKE ALL ON TABLE public.pitches FROM anon, authenticated;
REVOKE ALL ON TABLE public.pitch_skills FROM anon, authenticated;
REVOKE ALL ON TABLE public.pitch_evidence FROM anon, authenticated;
REVOKE ALL ON TABLE public.pitch_catalog FROM anon, authenticated;
REVOKE ALL ON TABLE public.projects FROM anon, authenticated;
REVOKE ALL ON TABLE public.project_skills FROM anon, authenticated;
REVOKE ALL ON TABLE public.project_growth FROM anon, authenticated;
REVOKE ALL ON TABLE public.inbound_messages FROM anon, authenticated;
REVOKE ALL ON TABLE public.faq FROM anon, authenticated;
REVOKE ALL ON TABLE public.gemini_requests FROM anon, authenticated;
REVOKE ALL ON TABLE public.backups FROM anon, authenticated;
REVOKE ALL ON TABLE public.backup_sources FROM anon, authenticated;
REVOKE ALL ON TABLE public.transcripts FROM anon, authenticated;
REVOKE ALL ON TABLE public.backup_transcripts FROM anon, authenticated;
REVOKE ALL ON TABLE public.transcript_speakers FROM anon, authenticated;
REVOKE ALL ON TABLE public.transcript_turns FROM anon, authenticated;
REVOKE ALL ON TABLE public.transcript_chunks FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.pitch_detail(text[], public.skill_usage_mode)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_all_pitches() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_pitches(text[]) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_projects() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.get_skill(text, public.skill_usage_mode)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_skills(text[], public.skill_usage_mode)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_all_skills()
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.abuse_computed_score(smallint, text[], public.abuse_confidence)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_day_overview(date, boolean)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.send_message(text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_faq(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_faqs(text[]) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_all_faqs() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_gemini_usage() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.log_gemini_request() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.transcript_context(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.search_transcripts(text, extensions.vector, integer, text, uuid[])
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_transcript_window(uuid, numeric, numeric, numeric)
  FROM PUBLIC, anon, authenticated;

-- New objects created by postgres start with no anon/authenticated access.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- resume_reader: login role for resume work. Sees only non-private career rows
-- (and not rows whose parent is private). Set its password out of band:
--   ALTER ROLE resume_reader PASSWORD '...';
-- ---------------------------------------------------------------------------
CREATE ROLE resume_reader LOGIN NOINHERIT;
-- Lets PostgREST switch to resume_reader for get-jwt JWTs.
GRANT resume_reader TO authenticator;

GRANT USAGE ON SCHEMA public TO resume_reader;
GRANT SELECT ON TABLE public.employer TO resume_reader;
GRANT SELECT ON TABLE public.employment_titles TO resume_reader;
GRANT SELECT ON TABLE public.education_and_training TO resume_reader;
GRANT SELECT ON TABLE public.personal_growth TO resume_reader;
GRANT SELECT ON TABLE public.skills TO resume_reader;
GRANT SELECT ON TABLE public.skill_links TO resume_reader;
GRANT EXECUTE ON FUNCTION public.get_skill(text, public.skill_usage_mode) TO resume_reader;
GRANT EXECUTE ON FUNCTION public.get_skills(text[], public.skill_usage_mode) TO resume_reader;
GRANT EXECUTE ON FUNCTION public.get_all_skills() TO resume_reader;
GRANT SELECT ON TABLE public.pitches TO resume_reader;
GRANT SELECT ON TABLE public.pitch_skills TO resume_reader;
GRANT SELECT ON TABLE public.pitch_evidence TO resume_reader;
GRANT SELECT ON TABLE public.pitch_catalog TO resume_reader;
GRANT EXECUTE ON FUNCTION public.pitch_detail(text[], public.skill_usage_mode) TO resume_reader;
GRANT EXECUTE ON FUNCTION public.get_all_pitches() TO resume_reader;
GRANT EXECUTE ON FUNCTION public.get_pitches(text[]) TO resume_reader;
GRANT SELECT ON TABLE public.projects TO resume_reader;
GRANT SELECT ON TABLE public.project_skills TO resume_reader;
GRANT SELECT ON TABLE public.project_growth TO resume_reader;
GRANT EXECUTE ON FUNCTION public.get_projects() TO resume_reader;

CREATE POLICY resume_reader_select ON public.employer
  FOR SELECT TO resume_reader
  USING (NOT private);

-- Parent lookups below are themselves filtered by resume_reader's policies.
CREATE POLICY resume_reader_select ON public.employment_titles
  FOR SELECT TO resume_reader
  USING (NOT private AND EXISTS (SELECT 1 FROM public.employer e WHERE e.id = employer_id));

CREATE POLICY resume_reader_select ON public.education_and_training
  FOR SELECT TO resume_reader
  USING (NOT private);

CREATE POLICY resume_reader_select ON public.personal_growth
  FOR SELECT TO resume_reader
  USING (NOT private);

CREATE POLICY resume_reader_select ON public.skills
  FOR SELECT TO resume_reader
  USING (NOT private);

CREATE POLICY resume_reader_select ON public.skill_links
  FOR SELECT TO resume_reader
  USING (
    NOT private
    AND EXISTS (SELECT 1 FROM public.skills s WHERE s.id = skill_id)
    AND (employment_title_id IS NULL
      OR EXISTS (SELECT 1 FROM public.employment_titles t WHERE t.id = employment_title_id))
    AND (employer_id IS NULL
      OR EXISTS (SELECT 1 FROM public.employer e WHERE e.id = employer_id))
    AND (education_and_training_id IS NULL
      OR EXISTS (SELECT 1 FROM public.education_and_training d WHERE d.id = education_and_training_id))
    AND (personal_growth_id IS NULL
      OR EXISTS (SELECT 1 FROM public.personal_growth g WHERE g.id = personal_growth_id))
  );

CREATE POLICY resume_reader_select ON public.pitches
  FOR SELECT TO resume_reader
  USING (true);

CREATE POLICY resume_reader_select ON public.pitch_skills
  FOR SELECT TO resume_reader
  USING (EXISTS (SELECT 1 FROM public.skills s WHERE s.id = skill_id));

CREATE POLICY resume_reader_select ON public.pitch_evidence
  FOR SELECT TO resume_reader
  USING (
    (employment_title_id IS NULL
      OR EXISTS (SELECT 1 FROM public.employment_titles t WHERE t.id = employment_title_id))
    AND (employer_id IS NULL
      OR EXISTS (SELECT 1 FROM public.employer e WHERE e.id = employer_id))
    AND (education_and_training_id IS NULL
      OR EXISTS (SELECT 1 FROM public.education_and_training d WHERE d.id = education_and_training_id))
CREATE POLICY resume_reader_select ON public.projects
  FOR SELECT TO resume_reader
  USING (NOT private);

CREATE POLICY resume_reader_select ON public.project_skills
  FOR SELECT TO resume_reader
  USING (EXISTS (SELECT 1 FROM public.projects p WHERE p.id = project_id)
    AND EXISTS (SELECT 1 FROM public.skills s WHERE s.id = skill_id));

CREATE POLICY resume_reader_select ON public.project_growth
  FOR SELECT TO resume_reader
  USING (EXISTS (SELECT 1 FROM public.projects p WHERE p.id = project_id)
    AND EXISTS (SELECT 1 FROM public.personal_growth g WHERE g.id = personal_growth_id));

-- -    AND (personal_growth_id IS NULL
      OR EXISTS (SELECT 1 FROM public.personal_growth g WHERE g.id = personal_growth_id))
  );

-- ---------------------------------------------------------------------------
-- chat: login role for a career chat. Only the career functions plus the
-- tables they read (functions are SECURITY INVOKER), with resume_reader's
-- non-private row filters. Set its password out of band:
--   ALTER ROLE chat PASSWORD '...';
-- ---------------------------------------------------------------------------
CREATE ROLE chat LOGIN NOINHERIT;
-- Lets PostgREST switch to chat for get-jwt JWTs.
GRANT chat TO authenticator;

GRANT USAGE ON SCHEMA public TO chat;
GRANT EXECUTE ON FUNCTION public.get_skill(text, public.skill_usage_mode) TO chat;
GRANT EXECUTE ON FUNCTION public.get_skills(text[], public.skill_usage_mode) TO chat;
GRANT EXECUTE ON FUNCTION public.get_all_skills() TO chat;
GRANT EXECUTE ON FUNCTION public.pitch_detail(text[], public.skill_usage_mode) TO chat;
GRANT EXECUTE ON FUNCTION public.get_all_pitches() TO chat;
GRANT EXECUTE ON FUNCTION public.get_pitches(text[]) TO chat;
GRANT EXECUTE ON FUNCTION public.get_projects() TO chat;

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
GRANT SELECT ON TABLE public.projects TO chat;
GRANT SELECT ON TABLE public.project_skills TO chat;
GRANT SELECT ON TABLE public.project_growth TO chat;

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
ALTER POLICY resume_reader_select ON public.projects TO resume_reader, chat;
ALTER POLICY resume_reader_select ON public.project_skills TO resume_reader, chat;
ALTER POLICY resume_reader_select ON public.project_growth TO resume_reader, chat;

-- Write-only: chat can log messages but not read them back.
GRANT EXECUTE ON FUNCTION public.send_message(text, text) TO chat;
GRANT INSERT ON TABLE public.inbound_messages TO chat;
CREATE POLICY chat_insert ON public.inbound_messages
  FOR INSERT TO chat
  WITH CHECK (true);

GRANT SELECT ON TABLE public.faq TO chat;
CREATE POLICY chat_read ON public.faq FOR SELECT TO chat USING (true);
GRANT EXECUTE ON FUNCTION public.get_faq(text) TO chat;
GRANT EXECUTE ON FUNCTION public.get_faqs(text[]) TO chat;
GRANT EXECUTE ON FUNCTION public.get_all_faqs() TO chat;

-- Read-only: chat writes the window only through log_gemini_request.
GRANT SELECT ON TABLE public.gemini_requests TO chat;
CREATE POLICY chat_read ON public.gemini_requests FOR SELECT TO chat USING (true);
GRANT EXECUTE ON FUNCTION public.get_gemini_usage() TO chat;
GRANT EXECUTE ON FUNCTION public.log_gemini_request() TO chat;

-- ---------------------------------------------------------------------------
-- transcriber: login role for scripts/vector (ingest + search). Direct DB
-- connection, not PostgREST. Writes transcripts; reads backups. backups and
-- backup_sources are written only through the MCP. No UPDATE: relabel = re-ingest.
-- Set its password out of band:
--   ALTER ROLE transcriber PASSWORD '...';
-- ---------------------------------------------------------------------------
CREATE ROLE transcriber LOGIN NOINHERIT;

GRANT USAGE ON SCHEMA public TO transcriber;
-- vector type and <=> operator.
GRANT USAGE ON SCHEMA extensions TO transcriber;
GRANT EXECUTE ON FUNCTION public.transcript_context(uuid) TO transcriber;
GRANT EXECUTE ON FUNCTION public.search_transcripts(text, extensions.vector, integer, text, uuid[]) TO transcriber;
GRANT EXECUTE ON FUNCTION public.get_transcript_window(uuid, numeric, numeric, numeric) TO transcriber;

GRANT SELECT, INSERT, DELETE ON TABLE public.transcripts TO transcriber;
GRANT SELECT, INSERT, DELETE ON TABLE public.transcript_speakers TO transcriber;
GRANT SELECT, INSERT, DELETE ON TABLE public.transcript_turns TO transcriber;
GRANT SELECT, INSERT, DELETE ON TABLE public.transcript_chunks TO transcriber;
GRANT SELECT, INSERT ON TABLE public.backup_transcripts TO transcriber;
GRANT SELECT ON TABLE public.backups TO transcriber;

-- Grants above limit the verbs each policy allows.
CREATE POLICY transcriber_all ON public.transcripts
  FOR ALL TO transcriber
  USING (true) WITH CHECK (true);

CREATE POLICY transcriber_all ON public.transcript_speakers
  FOR ALL TO transcriber
  USING (true) WITH CHECK (true);

CREATE POLICY transcriber_all ON public.transcript_turns
  FOR ALL TO transcriber
  USING (true) WITH CHECK (true);

CREATE POLICY transcriber_all ON public.transcript_chunks
  FOR ALL TO transcriber
  USING (true) WITH CHECK (true);

CREATE POLICY transcriber_all ON public.backup_transcripts
  FOR ALL TO transcriber
  USING (true) WITH CHECK (true);

CREATE POLICY transcriber_read ON public.backups
  FOR SELECT TO transcriber
  USING (true);

-- pg_stat_statements: PUBLIC by default; restrict to API roles so login roles
-- (transcriber) can't read other roles' query text.
GRANT SELECT ON extensions.pg_stat_statements, extensions.pg_stat_statements_info TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION extensions.pg_stat_statements(boolean), extensions.pg_stat_statements_info() TO anon, authenticated, service_role;
REVOKE SELECT ON extensions.pg_stat_statements, extensions.pg_stat_statements_info FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION extensions.pg_stat_statements(boolean), extensions.pg_stat_statements_info() FROM PUBLIC;
-- net (pg_net) also grants PUBLIC, but is owned by supabase_admin; postgres
-- cannot revoke it. transcriber can still reach net.http_* via PUBLIC.
