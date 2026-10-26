-- Display all timestamptz values in Central time (storage stays UTC).
ALTER DATABASE postgres SET timezone TO 'America/Chicago';

-- Store timestamps to the second.
ALTER TABLE public.application_conversations
  ALTER COLUMN occurred_at TYPE timestamptz(0);
ALTER TABLE public.todolist
  ALTER COLUMN target_date TYPE timestamptz(0),
  ALTER COLUMN deadline_date TYPE timestamptz(0);

-- Indexes and ON DELETE rules for tables defined in earlier migrations.

CREATE INDEX applications_user_id_idx
  ON public.applications (user_id);

CREATE INDEX application_interviews_application_id_idx
  ON public.application_interviews (application_id);

CREATE INDEX application_conversations_application_id_idx
  ON public.application_conversations (application_id);

CREATE INDEX todolist_application_id_idx
  ON public.todolist (application_id);

CREATE INDEX todolist_communication_id_idx
  ON public.todolist (communication_id);

CREATE INDEX todolist_target_date_idx
  ON public.todolist (target_date);

CREATE INDEX todolist_deadline_date_idx
  ON public.todolist (deadline_date);

CREATE INDEX personal_info_and_docs_user_id_idx
  ON public.personal_info_and_docs (user_id);

CREATE INDEX application_logins_login_id_idx
  ON public.application_logins (login_id);

CREATE INDEX abuse_application_id_idx
  ON public.abuse (application_id);

CREATE INDEX abuse_communication_id_idx
  ON public.abuse (communication_id);

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

CREATE INDEX pitch_skills_skill_id_idx
  ON public.pitch_skills (skill_id);

CREATE INDEX pitch_evidence_pitch_id_idx
  ON public.pitch_evidence (pitch_id);

-- Covers FKs without ON DELETE: deleting a parent otherwise scans the table.
CREATE INDEX pitch_evidence_employment_title_id_idx
  ON public.pitch_evidence (employment_title_id);

CREATE INDEX pitch_evidence_employer_id_idx
  ON public.pitch_evidence (employer_id);

CREATE INDEX pitch_evidence_education_and_training_id_idx
  ON public.pitch_evidence (education_and_training_id);

CREATE INDEX pitch_evidence_personal_growth_id_idx
  ON public.pitch_evidence (personal_growth_id);

CREATE INDEX abuse_impact_band_idx
  ON public.abuse (impact_band);

CREATE INDEX abuse_severity_band_idx
  ON public.abuse (severity_band);

-- get_skill() matches on lower(name).
CREATE INDEX skills_lower_name_idx
  ON public.skills (lower(name));

-- ---------------------------------------------------------------------------
-- Delete rules
-- ---------------------------------------------------------------------------
-- Pitch links follow their pitch, skill or proof row. pitch_evidence needs
-- exactly one target, so SET NULL would fail its check; cascade instead.
ALTER TABLE public.pitch_skills
  DROP CONSTRAINT pitch_skills_pitch_id_fkey,
  ADD CONSTRAINT pitch_skills_pitch_id_fkey
    FOREIGN KEY (pitch_id) REFERENCES public.pitches (id) ON DELETE CASCADE,
  DROP CONSTRAINT pitch_skills_skill_id_fkey,
  ADD CONSTRAINT pitch_skills_skill_id_fkey
    FOREIGN KEY (skill_id) REFERENCES public.skills (id) ON DELETE CASCADE;

ALTER TABLE public.pitch_evidence
  DROP CONSTRAINT pitch_evidence_pitch_id_fkey,
  ADD CONSTRAINT pitch_evidence_pitch_id_fkey
    FOREIGN KEY (pitch_id) REFERENCES public.pitches (id) ON DELETE CASCADE,
  DROP CONSTRAINT pitch_evidence_employment_title_id_fkey,
  ADD CONSTRAINT pitch_evidence_employment_title_id_fkey
    FOREIGN KEY (employment_title_id) REFERENCES public.employment_titles (id) ON DELETE CASCADE,
  DROP CONSTRAINT pitch_evidence_employer_id_fkey,
  ADD CONSTRAINT pitch_evidence_employer_id_fkey
    FOREIGN KEY (employer_id) REFERENCES public.employer (id) ON DELETE CASCADE,
  DROP CONSTRAINT pitch_evidence_education_and_training_id_fkey,
  ADD CONSTRAINT pitch_evidence_education_and_training_id_fkey
    FOREIGN KEY (education_and_training_id) REFERENCES public.education_and_training (id) ON DELETE CASCADE,
  DROP CONSTRAINT pitch_evidence_personal_growth_id_fkey,
  ADD CONSTRAINT pitch_evidence_personal_growth_id_fkey
    FOREIGN KEY (personal_growth_id) REFERENCES public.personal_growth (id) ON DELETE CASCADE;

-- Rubric bands are fixed; block deleting one that scored rows still use.
ALTER TABLE public.abuse
  DROP CONSTRAINT abuse_impact_band_fkey,
  ADD CONSTRAINT abuse_impact_band_fkey
    FOREIGN KEY (impact_band) REFERENCES public.abuse_impact_rubric (band) ON DELETE RESTRICT,
  DROP CONSTRAINT abuse_severity_band_fkey,
  ADD CONSTRAINT abuse_severity_band_fkey
    FOREIGN KEY (severity_band) REFERENCES public.abuse_severity_rubric (band) ON DELETE RESTRICT;
