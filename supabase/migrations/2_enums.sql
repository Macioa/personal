-- ---------------------------------------------------------------------------
-- Enums for all domains; runs before any table that uses them.
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

CREATE TYPE public.abuse_confidence AS ENUM (
  'high',
  'low',
  'insufficient_evidence'
);

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
  'clearance',
  'other'
);

CREATE TYPE public.skill_usage_mode AS ENUM (
  'precise',
  'start_to_end'
);

CREATE TYPE public.pitch_type AS ENUM (
  'technical',
  'leadership',
  'delivery',
  'domain',
  'collaboration',
  'other'
);

CREATE TYPE public.backup_type AS ENUM (
  'message',
  'video',
  'audio'
);

CREATE TYPE public.transcript_source AS ENUM (
  'whisper',
  'fathom',
  'manual'
);

-- Labels only. Real mailbox addresses stay in the database, not in git.
CREATE TYPE public.personal_email_used AS ENUM (
  'outlook',
  'gmail'
);
