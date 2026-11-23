-- Display all timestamptz values in Central time (storage stays UTC).
ALTER DATABASE postgres SET timezone TO 'America/Chicago';

-- Indexes for tables defined in earlier migrations.

CREATE INDEX applications_user_id_idx
  ON public.applications (user_id);

CREATE INDEX application_interviews_application_id_idx
  ON public.application_interviews (application_id);

CREATE INDEX application_conversations_application_id_idx
  ON public.application_conversations (application_id);

CREATE INDEX todolist_application_id_idx
  ON public.todolist (application_id);

CREATE INDEX todolist_application_conversation_id_idx
  ON public.todolist (application_conversation_id);

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

CREATE INDEX abuse_application_conversation_id_idx
  ON public.abuse (application_conversation_id);

CREATE INDEX employment_titles_employer_id_idx
  ON public.employment_titles (employer_id);

CREATE INDEX employment_resumedesc_bullets_employment_title_id_idx
  ON public.employment_resumedesc_bullets (employment_title_id);

CREATE INDEX employer_employer_portals_employer_portal_id_idx
  ON public.employer_employer_portals (employer_portal_id);

CREATE INDEX employer_job_references_job_reference_id_idx
  ON public.employer_job_references (job_reference_id);

CREATE INDEX skill_links_skill_id_idx
  ON public.skill_links (skill_id);

CREATE INDEX skill_links_employment_title_id_idx
  ON public.skill_links (employment_title_id);

CREATE INDEX skill_links_education_and_training_id_idx
  ON public.skill_links (education_and_training_id);

CREATE INDEX skill_links_personal_growth_id_idx
  ON public.skill_links (personal_growth_id);

CREATE INDEX pitch_skills_skill_id_idx
  ON public.pitch_skills (skill_id);

CREATE INDEX project_skills_skill_id_idx
  ON public.project_skills (skill_id);

CREATE INDEX project_growth_personal_growth_id_idx
  ON public.project_growth (personal_growth_id);

CREATE INDEX pitch_projects_project_id_idx
  ON public.pitch_projects (project_id);

CREATE INDEX pitch_evidence_pitch_id_idx
  ON public.pitch_evidence (pitch_id);

-- Covers FKs without ON DELETE: deleting a parent otherwise scans the table.
CREATE INDEX pitch_evidence_employment_title_id_idx
  ON public.pitch_evidence (employment_title_id);

CREATE INDEX pitch_evidence_employment_resumedesc_bullet_id_idx
  ON public.pitch_evidence (employment_resumedesc_bullet_id);

CREATE INDEX pitch_evidence_education_and_training_id_idx
  ON public.pitch_evidence (education_and_training_id);

CREATE INDEX pitch_growth_personal_growth_id_idx
  ON public.pitch_growth (personal_growth_id);

CREATE INDEX abuse_impact_band_idx
  ON public.abuse (impact_band);

CREATE INDEX abuse_severity_band_idx
  ON public.abuse (severity_band);

-- log_gemini_request() trims by sent_at.
CREATE INDEX gemini_requests_sent_at_idx ON public.gemini_requests (sent_at);

-- get_skill() matches on lower(name).
CREATE UNIQUE INDEX skills_lower_name_idx
  ON public.skills (lower(name));

CREATE INDEX skill_group_members_group_id_idx
  ON public.skill_group_members (group_id);

CREATE INDEX transcript_turns_speaker_idx
  ON public.transcript_turns (transcript_id, speaker_no);

-- At most one self speaker per transcript.
CREATE UNIQUE INDEX transcript_speakers_one_self_idx
  ON public.transcript_speakers (transcript_id) WHERE is_self;
