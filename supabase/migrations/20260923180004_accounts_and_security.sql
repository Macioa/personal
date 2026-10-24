-- DB config only: account-specific values, then RLS, grants, revokes, roles and
-- policies for tables defined in earlier migrations. No tables or data.
--
-- ACCOUNT-SPECIFIC: the values below intentionally differ from live. Git keeps
-- placeholders only; replace them per database before applying.

-- ---------------------------------------------------------------------------
-- Account-specific values
-- ---------------------------------------------------------------------------
-- Labels only. Real mailbox addresses stay in the database, not in git.
CREATE TYPE public.personal_email_used AS ENUM (
  'outlook',
  'gmail'
);

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

ALTER TABLE public.applications FORCE ROW LEVEL SECURITY;
ALTER TABLE public.application_interviews FORCE ROW LEVEL SECURITY;
ALTER TABLE public.application_conversations FORCE ROW LEVEL SECURITY;
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

REVOKE ALL ON TABLE public.applications FROM anon, authenticated;
REVOKE ALL ON TABLE public.application_interviews FROM anon, authenticated;
REVOKE ALL ON TABLE public.application_conversations FROM anon, authenticated;
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
REVOKE EXECUTE ON FUNCTION public.pitch_detail(text[], public.skill_usage_mode)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- resume_reader: login role for resume work. Sees only non-private career rows
-- (and not rows whose parent is private). Set its password out of band:
--   ALTER ROLE resume_reader PASSWORD '...';
-- ---------------------------------------------------------------------------
CREATE ROLE resume_reader LOGIN NOINHERIT;

GRANT USAGE ON SCHEMA public TO resume_reader;
GRANT SELECT ON TABLE public.employer TO resume_reader;
GRANT SELECT ON TABLE public.employment_titles TO resume_reader;
GRANT SELECT ON TABLE public.education_and_training TO resume_reader;
GRANT SELECT ON TABLE public.personal_growth TO resume_reader;
GRANT SELECT ON TABLE public.skills TO resume_reader;
GRANT SELECT ON TABLE public.skill_links TO resume_reader;
GRANT EXECUTE ON FUNCTION public.get_skill(text, public.skill_usage_mode) TO resume_reader;
GRANT EXECUTE ON FUNCTION public.get_skills(text[], public.skill_usage_mode) TO resume_reader;
GRANT SELECT ON TABLE public.pitches TO resume_reader;
GRANT SELECT ON TABLE public.pitch_skills TO resume_reader;
GRANT SELECT ON TABLE public.pitch_evidence TO resume_reader;
GRANT SELECT ON TABLE public.pitch_catalog TO resume_reader;
GRANT EXECUTE ON FUNCTION public.pitch_detail(text[], public.skill_usage_mode) TO resume_reader;

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
    AND (personal_growth_id IS NULL
      OR EXISTS (SELECT 1 FROM public.personal_growth g WHERE g.id = personal_growth_id))
  );
