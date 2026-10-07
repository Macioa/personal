-- Full public schema for new databases only (single-go; not layered).
-- Matches the live Supabase public schema as of abuse scoring + rubrics.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
CREATE TYPE public.interview_type AS ENUM (
  'screen',
  'first_round',
  'technical',
  'cultural',
  'final',
  'technical_exam',
  'other'
);

CREATE TYPE public.meeting_service AS ENUM (
  'teams',
  'google',
  'skype',
  'discord',
  'telegram',
  'whatsapp',
  'proprietary',
  'other_video',
  'other_leetcode'
);

CREATE TYPE public.conversation_type AS ENUM (
  'phone',
  'dm',
  'email',
  'other'
);

CREATE TYPE public.personal_info_doc_type AS ENUM (
  'text_info',
  'pdf',
  'image',
  'other'
);

-- Labels only. Real mailbox addresses stay in the database, not in git.
CREATE TYPE public.personal_email_used AS ENUM (
  'outlook',
  'gmail'
);

CREATE TYPE public.abuse_confidence AS ENUM (
  'high',
  'low',
  'insufficient_evidence'
);

-- ---------------------------------------------------------------------------
-- Core application tracking
-- ---------------------------------------------------------------------------
CREATE TABLE public.applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Replace this placeholder with your auth.users ID before applying.
  user_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::uuid
    REFERENCES auth.users (id) ON DELETE CASCADE,
  company text NOT NULL,
  company_link text,
  position text NOT NULL,
  location_or_remote text NOT NULL,
  recruiter_name text,
  recruiter_email text,
  applied date NOT NULL,
  official_job_desc text NOT NULL,
  job_post_link text NOT NULL,
  job_site_portal text,
  cover_letter text,
  pending boolean NOT NULL DEFAULT true,
  rejected boolean NOT NULL DEFAULT false,
  rejection_reason text,
  recruiting_agency text,
  which_personal_email_used public.personal_email_used
);

CREATE TABLE public.application_interviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.applications (id) ON DELETE CASCADE,
  type public.interview_type NOT NULL,
  onsite boolean NOT NULL DEFAULT false,
  attendees text[] NOT NULL DEFAULT '{}',
  attendee_emails text[] NOT NULL DEFAULT '{}',
  meeting_service public.meeting_service,
  meeting_link text,
  meeting_invite text,
  meeting_notes text
);

CREATE TABLE public.application_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.applications (id) ON DELETE CASCADE,
  type public.conversation_type NOT NULL,
  short_summary varchar(500),
  content text
);

CREATE TABLE public.personal_info_and_docs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Replace this placeholder with your auth.users ID before applying.
  user_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::uuid
    REFERENCES auth.users (id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  type public.personal_info_doc_type NOT NULL,
  intended_use text,
  content_blob bytea,
  content_blob_filename text,
  content_string text,
  version integer NOT NULL DEFAULT 0
);

CREATE TABLE public.logins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL,
  password text NOT NULL,
  login_url text,
  oauth boolean NOT NULL DEFAULT false,
  oauth_email text
);

CREATE TABLE public.application_logins (
  application_id uuid NOT NULL REFERENCES public.applications (id) ON DELETE CASCADE,
  login_id uuid NOT NULL REFERENCES public.logins (id) ON DELETE CASCADE,
  PRIMARY KEY (application_id, login_id)
);

CREATE INDEX applications_user_id_idx
  ON public.applications (user_id);

CREATE INDEX application_interviews_application_id_idx
  ON public.application_interviews (application_id);

CREATE INDEX application_conversations_application_id_idx
  ON public.application_conversations (application_id);

CREATE INDEX personal_info_and_docs_user_id_idx
  ON public.personal_info_and_docs (user_id);

CREATE INDEX application_logins_login_id_idx
  ON public.application_logins (login_id);

-- ---------------------------------------------------------------------------
-- Abuse scoring helper (needed before generated columns)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.abuse_computed_score(
  p_band smallint,
  p_escalators text[],
  p_confidence public.abuse_confidence
) RETURNS smallint
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_confidence IS NULL THEN NULL
    WHEN p_confidence = 'insufficient_evidence'::public.abuse_confidence THEN NULL
    WHEN p_band IS NULL THEN NULL
    ELSE (p_band * 2 - 1)
      + CASE WHEN coalesce(cardinality(p_escalators), 0) > 0 THEN 1 ELSE 0 END
  END::smallint;
$$;

-- ---------------------------------------------------------------------------
-- Abuse rubrics / escalator catalogs
-- ---------------------------------------------------------------------------
CREATE TABLE public.abuse_impact_rubric (
  band smallint PRIMARY KEY CHECK (band BETWEEN 1 AND 5),
  label text NOT NULL,
  description text NOT NULL
);

CREATE TABLE public.abuse_severity_rubric (
  band smallint PRIMARY KEY CHECK (band BETWEEN 1 AND 5),
  label text NOT NULL,
  description text NOT NULL
);

INSERT INTO public.abuse_impact_rubric (band, label, description) VALUES
  (1, 'Under 1 hour',
   'Under 1 hour'),
  (2, '1–4 hours / one stage',
   '1–4 h, or one stage wasted'),
  (3, '4–10 hours / take-home / time off',
   '4–10 h, a take-home, or time off used'),
  (4, '10–25 hours / lost opportunity / job at risk',
   '10–25 h, a lost opportunity, or your current job put at risk'),
  (5, 'Over 25 hours / money lost / identity theft',
   'Over 25 h, money lost, or identity theft');

INSERT INTO public.abuse_severity_rubric (band, label, description) VALUES
  (1, 'Careless',
   'Careless: wrong name, template reply, curt'),
  (2, 'Disrespectful',
   'Disrespectful: ghosting after contact, no-show, patronizing'),
  (3, 'Deceptive or coercive',
   'Deceptive or coercive: ghost job, bait-and-switch, résumé sent without consent'),
  (4, 'Mocking or derogatory',
   'Mocking or derogatory: imitating you, insults, yelling, remarks about a protected trait'),
  (5, 'Hostile or unlawful',
   'Hostile or unlawful: slurs, sexual advances, threats, retaliation, scams');

COMMENT ON TABLE public.abuse_impact_rubric IS
  'Impact band 1–5 guide. Score = band×2−1 (+1 if any impact escalator).';
COMMENT ON TABLE public.abuse_severity_rubric IS
  'Severity/audacity band 1–5 guide. Score = band×2−1 (+1 if any severity escalator).';

CREATE TABLE public.abuse_impact_escalator (
  code text PRIMARY KEY,
  description text NOT NULL
);

CREATE TABLE public.abuse_severity_escalator (
  code text PRIMARY KEY,
  description text NOT NULL
);

INSERT INTO public.abuse_impact_escalator (code, description) VALUES
  ('one_stage_wasted', 'One interview/application stage wasted'),
  ('take_home', 'Take-home assignment required or completed'),
  ('time_off_used', 'Used PTO / time off from current job'),
  ('lost_opportunity', 'Concrete other opportunity lost'),
  ('current_job_at_risk', 'Current employment put at risk'),
  ('money_lost', 'Out-of-pocket money lost'),
  ('identity_theft', 'Identity theft or credential misuse');

INSERT INTO public.abuse_severity_escalator (code, description) VALUES
  ('wrong_name_or_template', 'Wrong name or obvious template reply'),
  ('ghosting_after_contact', 'Ghosting after substantive contact'),
  ('no_show', 'No-show to a scheduled meeting'),
  ('patronizing', 'Patronizing tone or treatment'),
  ('ghost_job', 'Ghost job / role never real'),
  ('bait_and_switch', 'Bait-and-switch on role, pay, or terms'),
  ('resume_without_consent', 'Résumé or materials shared without consent'),
  ('imitation', 'Imitating speech, accent, mannerisms, or identity'),
  ('insults_or_yelling', 'Insults, yelling, or overt hostility short of threats'),
  ('protected_trait_remark', 'Remark targeting a protected trait'),
  ('slurs', 'Slurs'),
  ('sexual_advances', 'Sexual advances or harassment'),
  ('threats', 'Threats'),
  ('retaliation', 'Retaliation'),
  ('scams', 'Scams or fraud');

COMMENT ON TABLE public.abuse_impact_escalator IS
  'Fixed impact escalator codes. Any one on a row adds +1 to impact_score; they do not stack.';
COMMENT ON TABLE public.abuse_severity_escalator IS
  'Fixed severity escalator codes. Any one on a row adds +1 to severity_score; they do not stack.';

-- ---------------------------------------------------------------------------
-- Abuse
-- ---------------------------------------------------------------------------
CREATE TABLE public.abuse (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.applications (id) ON DELETE CASCADE,
  gaslighting boolean NOT NULL DEFAULT false,
  direct_imitation boolean NOT NULL DEFAULT false,
  time_wasting boolean NOT NULL DEFAULT false,
  accusational boolean NOT NULL DEFAULT false,
  ghosting_after_otherwise_indicated boolean NOT NULL DEFAULT false,
  excess_phone_calls boolean NOT NULL DEFAULT false,
  other text,
  "desc" text,
  derogatory boolean NOT NULL DEFAULT false,
  communication_id uuid REFERENCES public.application_conversations (id) ON DELETE SET NULL,
  indirect_imitation boolean NOT NULL DEFAULT false,
  evidence_quote text,
  hours_lost numeric(8, 2),
  impact_band smallint REFERENCES public.abuse_impact_rubric (band),
  severity_band smallint REFERENCES public.abuse_severity_rubric (band),
  impact_escalators text[] NOT NULL DEFAULT '{}',
  severity_escalators text[] NOT NULL DEFAULT '{}',
  protected_trait boolean NOT NULL DEFAULT false,
  confidence public.abuse_confidence,
  rationale varchar(300),
  rubric_version text,
  scored_by text,
  impact_score smallint
    GENERATED ALWAYS AS (
      public.abuse_computed_score(impact_band, impact_escalators, confidence)
    ) STORED,
  severity_score smallint
    GENERATED ALWAYS AS (
      public.abuse_computed_score(severity_band, severity_escalators, confidence)
    ) STORED,
  CONSTRAINT abuse_impact_band_range_chk
    CHECK (impact_band IS NULL OR impact_band BETWEEN 1 AND 5),
  CONSTRAINT abuse_severity_band_range_chk
    CHECK (severity_band IS NULL OR severity_band BETWEEN 1 AND 5),
  CONSTRAINT abuse_hours_lost_nonneg_chk
    CHECK (hours_lost IS NULL OR hours_lost >= 0),
  CONSTRAINT abuse_protected_trait_severity_floor_chk
    CHECK (NOT protected_trait OR severity_band IS NULL OR severity_band >= 4),
  CONSTRAINT abuse_impact_escalators_known_chk
    CHECK (
      impact_escalators <@ ARRAY[
        'one_stage_wasted',
        'take_home',
        'time_off_used',
        'lost_opportunity',
        'current_job_at_risk',
        'money_lost',
        'identity_theft'
      ]::text[]
    ),
  CONSTRAINT abuse_severity_escalators_known_chk
    CHECK (
      severity_escalators <@ ARRAY[
        'wrong_name_or_template',
        'ghosting_after_contact',
        'no_show',
        'patronizing',
        'ghost_job',
        'bait_and_switch',
        'resume_without_consent',
        'imitation',
        'insults_or_yelling',
        'protected_trait_remark',
        'slurs',
        'sexual_advances',
        'threats',
        'retaliation',
        'scams'
      ]::text[]
    ),
  CONSTRAINT abuse_impact_score_range_chk
    CHECK (impact_score IS NULL OR impact_score BETWEEN 1 AND 10),
  CONSTRAINT abuse_severity_score_range_chk
    CHECK (severity_score IS NULL OR severity_score BETWEEN 1 AND 10)
);

CREATE INDEX abuse_application_id_idx
  ON public.abuse (application_id);

CREATE INDEX abuse_communication_id_idx
  ON public.abuse (communication_id);

COMMENT ON COLUMN public.abuse.evidence_quote IS
  'Exact quote first. For ghosting or no-shows, write dated facts instead.';
COMMENT ON COLUMN public.abuse.hours_lost IS
  'Time wasted; used to choose impact_band.';
COMMENT ON COLUMN public.abuse.impact_band IS
  '1–5 from abuse_impact_rubric.';
COMMENT ON COLUMN public.abuse.severity_band IS
  '1–5 from abuse_severity_rubric. If protected_trait, must be >= 4.';
COMMENT ON COLUMN public.abuse.impact_escalators IS
  'Codes from abuse_impact_escalator. Any one adds +1 to impact_score; no stacking.';
COMMENT ON COLUMN public.abuse.severity_escalators IS
  'Codes from abuse_severity_escalator. Any one adds +1 to severity_score; no stacking.';
COMMENT ON COLUMN public.abuse.protected_trait IS
  'When true, severity_band must be at least 4.';
COMMENT ON COLUMN public.abuse.impact_score IS
  'Generated: band×2−1, +1 if any impact escalator; null when confidence is insufficient_evidence.';
COMMENT ON COLUMN public.abuse.severity_score IS
  'Generated: band×2−1, +1 if any severity escalator; null when confidence is insufficient_evidence.';
COMMENT ON COLUMN public.abuse.confidence IS
  'high | low | insufficient_evidence. insufficient_evidence leaves scores null.';
COMMENT ON COLUMN public.abuse.rationale IS
  'Up to 300 characters naming the rubric example matched.';
COMMENT ON COLUMN public.abuse.rubric_version IS
  'Version of the scoring guide used.';
COMMENT ON COLUMN public.abuse.scored_by IS
  'Model or person that scored the row.';
COMMENT ON COLUMN public.abuse.indirect_imitation IS
  'Indirect imitation (distinct from direct_imitation).';

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

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
