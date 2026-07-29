-- Application tracking schema (Postgres)

CREATE TYPE interview_type AS ENUM (
  'screen',
  'first_round',
  'technical',
  'cultural',
  'final',
  'technical_exam',
  'other'
);

CREATE TYPE meeting_service AS ENUM (
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

CREATE TYPE conversation_type AS ENUM (
  'phone',
  'dm',
  'email',
  'other'
);

CREATE TYPE personal_info_doc_type AS ENUM (
  'text_info',
  'pdf',
  'image',
  'other'
);

CREATE TABLE applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Replace this placeholder with your auth.users ID before applying.
  user_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'
    REFERENCES auth.users (id) ON DELETE CASCADE,
  company text NOT NULL,
  company_link text,
  recruiting_agency text,
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
  rejection_reason text
);

CREATE TABLE application_interviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES applications (id) ON DELETE CASCADE,
  type interview_type NOT NULL,
  onsite boolean NOT NULL DEFAULT false,
  attendees text[] NOT NULL DEFAULT '{}',
  attendee_emails text[] NOT NULL DEFAULT '{}',
  meeting_service meeting_service,
  meeting_link text,
  meeting_invite text,
  meeting_notes text
);

CREATE TABLE application_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES applications (id) ON DELETE CASCADE,
  type conversation_type NOT NULL,
  short_summary varchar(500),
  content text
);

CREATE TABLE personal_info_and_docs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Replace this placeholder with your auth.users ID before applying.
  user_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'
    REFERENCES auth.users (id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  type personal_info_doc_type NOT NULL,
  intended_use text,
  content_blob bytea,
  content_blob_filename text,
  content_string text,
  version integer NOT NULL DEFAULT 0
);

CREATE INDEX application_interviews_application_id_idx
  ON application_interviews (application_id);

CREATE INDEX application_conversations_application_id_idx
  ON application_conversations (application_id);

CREATE INDEX applications_user_id_idx
  ON applications (user_id);

CREATE INDEX personal_info_and_docs_user_id_idx
  ON personal_info_and_docs (user_id);
