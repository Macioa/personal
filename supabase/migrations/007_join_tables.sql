-- Join and link tables (many-to-many and exactly-one-target links).
-- Runs after the tables they reference (3_, 4_, 6_).

-- ---------------------------------------------------------------------------
-- Applications
-- ---------------------------------------------------------------------------
CREATE TABLE public.application_logins (
  application_id uuid NOT NULL REFERENCES public.applications (id) ON DELETE CASCADE,
  login_id uuid NOT NULL REFERENCES public.logins (id) ON DELETE CASCADE,
  PRIMARY KEY (application_id, login_id)
);

-- ---------------------------------------------------------------------------
-- Resume
-- ---------------------------------------------------------------------------
CREATE TABLE public.skill_group_members (
  skill_id uuid NOT NULL REFERENCES public.skills (id) ON DELETE CASCADE,
  group_id uuid NOT NULL REFERENCES public.skill_groups (id) ON DELETE CASCADE,
  PRIMARY KEY (skill_id, group_id)
);

CREATE TABLE public.employer_employer_portals (
  employer_id uuid NOT NULL REFERENCES public.employer (id) ON DELETE CASCADE,
  employer_portal_id uuid NOT NULL REFERENCES public.employer_portals (id) ON DELETE CASCADE,
  PRIMARY KEY (employer_id, employer_portal_id)
);

CREATE TABLE public.employer_job_references (
  employer_id uuid NOT NULL REFERENCES public.employer (id) ON DELETE CASCADE,
  job_reference_id uuid NOT NULL REFERENCES public.job_references (id) ON DELETE CASCADE,
  PRIMARY KEY (employer_id, job_reference_id)
);

-- One row links a skill to exactly one of: title, education, growth.
CREATE TABLE public.skill_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_id uuid NOT NULL REFERENCES public.skills (id) ON DELETE CASCADE,
  employment_title_id uuid REFERENCES public.employment_titles (id) ON DELETE CASCADE,
  education_and_training_id uuid REFERENCES public.education_and_training (id) ON DELETE CASCADE,
  personal_growth_id uuid REFERENCES public.personal_growth (id) ON DELETE CASCADE,
  private boolean NOT NULL DEFAULT false,
  CONSTRAINT skill_links_exactly_one_target_chk
    CHECK (num_nonnulls(employment_title_id, education_and_training_id, personal_growth_id) = 1)
);

CREATE TABLE public.pitch_skills (
  pitch_id uuid NOT NULL REFERENCES public.pitches (id) ON DELETE CASCADE,
  skill_id uuid NOT NULL REFERENCES public.skills (id) ON DELETE CASCADE,
  PRIMARY KEY (pitch_id, skill_id)
);

-- One row links a pitch to exactly one proof: title, bullet, education.
-- Cascades: SET NULL would fail the exactly-one check.
CREATE TABLE public.pitch_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pitch_id uuid NOT NULL REFERENCES public.pitches (id) ON DELETE CASCADE,
  employment_title_id uuid REFERENCES public.employment_titles (id) ON DELETE CASCADE,
  employment_resumedesc_bullet_id uuid REFERENCES public.employment_resumedesc_bullets (id) ON DELETE CASCADE,
  education_and_training_id uuid REFERENCES public.education_and_training (id) ON DELETE CASCADE,
  note varchar(300),
  CONSTRAINT pitch_evidence_exactly_one_target_chk
    CHECK (num_nonnulls(employment_title_id, employment_resumedesc_bullet_id, education_and_training_id) = 1)
);

CREATE TABLE public.pitch_growth (
  pitch_id uuid NOT NULL REFERENCES public.pitches (id) ON DELETE CASCADE,
  personal_growth_id uuid NOT NULL REFERENCES public.personal_growth (id) ON DELETE CASCADE,
  PRIMARY KEY (pitch_id, personal_growth_id)
);

CREATE TABLE public.project_skills (
  project_id uuid NOT NULL REFERENCES public.projects (id) ON DELETE CASCADE,
  skill_id uuid NOT NULL REFERENCES public.skills (id) ON DELETE CASCADE,
  PRIMARY KEY (project_id, skill_id)
);

CREATE TABLE public.project_growth (
  project_id uuid NOT NULL REFERENCES public.projects (id) ON DELETE CASCADE,
  personal_growth_id uuid NOT NULL REFERENCES public.personal_growth (id) ON DELETE CASCADE,
  PRIMARY KEY (project_id, personal_growth_id)
);

CREATE TABLE public.pitch_projects (
  pitch_id uuid NOT NULL REFERENCES public.pitches (id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES public.projects (id) ON DELETE CASCADE,
  PRIMARY KEY (pitch_id, project_id)
);

CREATE TABLE public.alternate_skills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_name text NOT NULL UNIQUE,
  alternate_skill_ids uuid[] NOT NULL
);

COMMENT ON TABLE public.alternate_skills IS
  'Skills I lack mapped to direct competitors I have (skills.id). Used by resume selection.';
COMMENT ON COLUMN public.alternate_skills.skill_name IS 'Skill I do not have, as named in JDs.';
COMMENT ON COLUMN public.alternate_skills.alternate_skill_ids IS 'skills.id of direct competitors I have.';
COMMENT ON TABLE public.skill_group_members IS
  'Join: skills to groups (many-to-many).';
COMMENT ON COLUMN public.skill_links.private IS
  'True hides this link from resume_reader, so it is left out of skill totals.';

COMMENT ON TABLE public.pitch_skills IS
  'Durations: get_skills(names, mode). One mode per output.';
COMMENT ON TABLE public.pitch_evidence IS
  'Join table: pitches to the work that backs them. Facts the output may state.';
COMMENT ON TABLE public.pitch_growth IS
  'Join table: pitches to personal_growth rows that back them.';
COMMENT ON COLUMN public.pitch_evidence.note IS
  'Explains how the linked row supports the pitch.';
COMMENT ON TABLE public.project_skills IS
  'Join table: projects to skills used.';
COMMENT ON TABLE public.project_growth IS
  'Join table: projects to personal_growth rows they came from.';
COMMENT ON TABLE public.pitch_projects IS
  'Join table: pitches to projects that back them.';

-- ---------------------------------------------------------------------------
-- Backups and transcripts
-- ---------------------------------------------------------------------------
-- 1:1 backup -> exactly one communication or interview.
CREATE TABLE public.backup_sources (
  backup_id uuid PRIMARY KEY REFERENCES public.backups (id) ON DELETE CASCADE,
  application_conversation_id uuid UNIQUE REFERENCES public.application_conversations (id) ON DELETE CASCADE,
  interview_id uuid UNIQUE REFERENCES public.application_interviews (id) ON DELETE CASCADE,
  CONSTRAINT backup_sources_one_target_chk
    CHECK (num_nonnulls(application_conversation_id, interview_id) = 1)
);

-- 1:1 backup <-> transcript.
CREATE TABLE public.backup_transcripts (
  backup_id uuid PRIMARY KEY REFERENCES public.backups (id) ON DELETE CASCADE,
  transcript_id uuid NOT NULL UNIQUE REFERENCES public.transcripts (id) ON DELETE CASCADE
);
