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
  'other',
  'sms'
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
   'Disrespectful: promised follow-up and did not, no-show without follow-up, patronizing'),
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
  ('identity_theft', 'Identity theft or credential misuse'),
  ('psychological_torment', 'Psychological torment'),
  ('organized_harrassment', 'Organized harrassment');

INSERT INTO public.abuse_severity_escalator (code, description) VALUES
  ('wrong_name_or_template', 'Wrong name or obvious template reply'),
  ('ghosting_after_otherwise_indicated', 'Promised follow-up and did not'),
  ('no_show_without_follow_up', 'No-show without follow-up'),
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
  ('scams', 'Scams or fraud'),
  ('persistent_refusal_to_acknowledge', 'Persistent refusal to acknowledge'),
  ('strawman_response', 'Primary argument is ignored while irrelevant detail is contested'),
  ('request_to_run_unprotected_code_on_local', 'Request to run unprotected code on a local machine; a common "job" crypto scam'),
  ('persistent_interuption', 'Persistent interuption'),
  ('prioritized_job_details_over_candidate_details', 'Prioritized job details over candidate details');

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
  persistent_refusal_to_acknowledge boolean NOT NULL DEFAULT false,
  strawman_response boolean NOT NULL DEFAULT false,
  request_to_run_unprotected_code_on_local boolean NOT NULL DEFAULT false,
  persistent_interuption boolean NOT NULL DEFAULT false,
  prioritized_job_details_over_candidate_details boolean NOT NULL DEFAULT false,
  false_or_deceptive_reporting boolean NOT NULL DEFAULT false,
  repetition_without_acknowledgement_of_repetition boolean NOT NULL DEFAULT false,
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
        'identity_theft',
        'psychological_torment',
        'organized_harrassment'
      ]::text[]
    ),
  CONSTRAINT abuse_severity_escalators_known_chk
    CHECK (
      severity_escalators <@ ARRAY[
        'wrong_name_or_template',
        'ghosting_after_otherwise_indicated',
        'no_show_without_follow_up',
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
        'scams',
        'persistent_refusal_to_acknowledge',
        'strawman_response',
        'request_to_run_unprotected_code_on_local',
        'persistent_interuption',
        'prioritized_job_details_over_candidate_details'
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

COMMENT ON COLUMN public.abuse.ghosting_after_otherwise_indicated IS
  'True when they indicated they would follow up and did not.';
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
COMMENT ON COLUMN public.abuse.false_or_deceptive_reporting IS
  'False or deceptive reporting.';
COMMENT ON COLUMN public.abuse.repetition_without_acknowledgement_of_repetition IS
  'The same claim or request is repeated without acknowledging that it was already said.';

-- ---------------------------------------------------------------------------
-- Career history: employers, titles, portals, skills, education, growth
-- ---------------------------------------------------------------------------
CREATE TYPE public.skill_type AS ENUM (
  'hard',
  'soft',
  'both',
  'other'
);

CREATE TYPE public.education_type AS ENUM (
  'bachelors',
  'masters',
  'phd',
  'training',
  'certificate',
  'training_certificate',
  'other'
);

CREATE TYPE public.skill_usage_mode AS ENUM (
  'precise',
  'start_to_end'
);

CREATE TABLE public.employer (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  address text,
  phone text,
  website text,
  company_desc text,
  resume_desc text,
  end_title text,
  start_day integer,
  start_month integer,
  start_year integer,
  end_day integer,
  end_month integer,
  end_year integer
);

CREATE TABLE public.employment_titles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id uuid NOT NULL REFERENCES public.employer (id) ON DELETE CASCADE,
  name text,
  "desc" text,
  start_day integer,
  start_month integer,
  start_year integer,
  end_day integer,
  end_month integer,
  end_year integer,
  remote boolean
);

CREATE TABLE public.employer_portals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  url text,
  username text,
  w2_or_tax boolean,
  contains_contracts boolean
);

CREATE TABLE public.skills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  "desc" text,
  type public.skill_type
);

CREATE TABLE public.education_and_training (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  address text,
  phone text,
  website text,
  type public.education_type,
  desc_short text,
  desc_long text,
  completed boolean,
  accredited boolean,
  attending boolean,
  start_day integer,
  start_month integer,
  start_year integer,
  end_day integer,
  end_month integer,
  end_year integer,
  remote boolean
);

CREATE TABLE public.personal_growth (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  desc_short text,
  desc_long text,
  url text,
  other_info text,
  start_day integer,
  start_month integer,
  start_year integer,
  end_day integer,
  end_month integer,
  end_year integer
);

CREATE TABLE public.employer_employer_portals (
  employer_id uuid NOT NULL REFERENCES public.employer (id) ON DELETE CASCADE,
  employer_portal_id uuid NOT NULL REFERENCES public.employer_portals (id) ON DELETE CASCADE,
  PRIMARY KEY (employer_id, employer_portal_id)
);

-- One row links a skill to exactly one of: title, employer, education, growth.
CREATE TABLE public.skill_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_id uuid NOT NULL REFERENCES public.skills (id) ON DELETE CASCADE,
  employment_title_id uuid REFERENCES public.employment_titles (id) ON DELETE CASCADE,
  employer_id uuid REFERENCES public.employer (id) ON DELETE CASCADE,
  education_and_training_id uuid REFERENCES public.education_and_training (id) ON DELETE CASCADE,
  personal_growth_id uuid REFERENCES public.personal_growth (id) ON DELETE CASCADE,
  CONSTRAINT skill_links_exactly_one_target_chk
    CHECK (num_nonnulls(employment_title_id, employer_id, education_and_training_id, personal_growth_id) = 1)
);

CREATE INDEX employment_titles_employer_id_idx
  ON public.employment_titles (employer_id);

CREATE INDEX employer_employer_portals_employer_portal_id_idx
  ON public.employer_employer_portals (employer_portal_id);

CREATE INDEX skill_links_skill_id_idx
  ON public.skill_links (skill_id);

CREATE INDEX skill_links_employment_title_id_idx
  ON public.skill_links (employment_title_id);

CREATE INDEX skill_links_employer_id_idx
  ON public.skill_links (employer_id);

CREATE INDEX skill_links_education_and_training_id_idx
  ON public.skill_links (education_and_training_id);

CREATE INDEX skill_links_personal_growth_id_idx
  ON public.skill_links (personal_growth_id);

-- Usage spans come from the linked row's dates. Missing start parts default to
-- Jan 1; missing end parts default to the last day of the year/month; a null
-- end_year means ongoing (today). precise = union of spans with overlaps
-- merged; start_to_end = last_used - first_used.
CREATE OR REPLACE FUNCTION public.get_skill(
  p_skill text,
  p_mode public.skill_usage_mode DEFAULT 'start_to_end'
) RETURNS TABLE (
  skill_id uuid,
  name text,
  "desc" text,
  type public.skill_type,
  first_used date,
  last_used date,
  total_days integer
)
LANGUAGE sql
STABLE
AS $$
  WITH s AS (
    SELECT sk.id, sk.name, sk."desc", sk.type
    FROM public.skills sk
    WHERE lower(sk.name) = lower(p_skill)
  ),
  raw AS (
    SELECT l.skill_id,
      coalesce(t.start_year, e.start_year, ed.start_year, g.start_year) AS sy,
      coalesce(t.start_month, e.start_month, ed.start_month, g.start_month) AS sm,
      coalesce(t.start_day, e.start_day, ed.start_day, g.start_day) AS sd,
      coalesce(t.end_year, e.end_year, ed.end_year, g.end_year) AS ey,
      coalesce(t.end_month, e.end_month, ed.end_month, g.end_month) AS em,
      coalesce(t.end_day, e.end_day, ed.end_day, g.end_day) AS endd
    FROM public.skill_links l
    JOIN s ON s.id = l.skill_id
    LEFT JOIN public.employment_titles t ON t.id = l.employment_title_id
    LEFT JOIN public.employer e ON e.id = l.employer_id
    LEFT JOIN public.education_and_training ed ON ed.id = l.education_and_training_id
    LEFT JOIN public.personal_growth g ON g.id = l.personal_growth_id
  ),
  spans AS (
    SELECT skill_id,
      make_date(sy, coalesce(sm, 1), coalesce(sd, 1)) AS s,
      CASE
        WHEN ey IS NULL THEN current_date
        WHEN em IS NOT NULL AND endd IS NOT NULL THEN make_date(ey, em, endd)
        ELSE (make_date(ey, coalesce(em, 12), 1) + interval '1 month' - interval '1 day')::date
      END AS e
    FROM raw
    WHERE sy IS NOT NULL
  ),
  ordered AS (
    SELECT skill_id, s, e,
      max(e) OVER (PARTITION BY skill_id ORDER BY s, e
                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_max
    FROM spans
  ),
  grouped AS (
    SELECT skill_id, s, e,
      sum(CASE WHEN prev_max IS NULL OR s > prev_max THEN 1 ELSE 0 END)
        OVER (PARTITION BY skill_id ORDER BY s, e) AS grp
    FROM ordered
  ),
  merged AS (
    SELECT skill_id, min(s) AS s, max(e) AS e
    FROM grouped
    GROUP BY skill_id, grp
  ),
  agg AS (
    SELECT skill_id, min(s) AS first_used, max(e) AS last_used,
      sum(e - s)::integer AS precise_days
    FROM merged
    GROUP BY skill_id
  )
  SELECT s.id, s.name, s."desc", s.type, a.first_used, a.last_used,
    CASE
      WHEN p_mode = 'precise'::public.skill_usage_mode THEN a.precise_days
      ELSE (a.last_used - a.first_used)
    END
  FROM s
  LEFT JOIN agg a ON a.skill_id = s.id;
$$;

CREATE OR REPLACE FUNCTION public.get_skills(
  p_skills text[],
  p_mode public.skill_usage_mode DEFAULT 'start_to_end'
) RETURNS TABLE (
  skill_id uuid,
  name text,
  "desc" text,
  type public.skill_type,
  first_used date,
  last_used date,
  total_days integer
)
LANGUAGE sql
STABLE
AS $$
  SELECT g.*
  FROM unnest(p_skills) AS u(skill)
  CROSS JOIN LATERAL public.get_skill(u.skill, p_mode) AS g;
$$;

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

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
