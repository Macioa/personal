-- ---------------------------------------------------------------------------
-- Career history: employers, titles, portals, skills, education, growth
-- ---------------------------------------------------------------------------
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
  end_year integer,
  private boolean NOT NULL DEFAULT false
);

CREATE TABLE public.employment_titles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id uuid NOT NULL REFERENCES public.employer (id) ON DELETE CASCADE,
  name text,
  "desc" text,
  bullets text[],
  location text,
  start_day integer,
  start_month integer,
  start_year integer,
  end_day integer,
  end_month integer,
  end_year integer,
  remote boolean,
  private boolean NOT NULL DEFAULT false
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
  type public.skill_type,
  private boolean NOT NULL DEFAULT false,
  priority integer,
  embedding extensions.vector(384),
  aliases text[] NOT NULL DEFAULT '{}'
);

CREATE TABLE public.skill_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  "desc" text,
  embedding extensions.vector(384)
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
  remote boolean,
  private boolean NOT NULL DEFAULT false,
  gpa text NOT NULL DEFAULT 'N/A'
    CONSTRAINT education_and_training_gpa_chk CHECK (gpa = 'N/A' OR gpa ~ '^[0-9]+(\.[0-9]+)?$'),
  identification_number text,
  issuing_authority text,
  specialty text
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
  end_year integer,
  private boolean NOT NULL DEFAULT false
);

COMMENT ON COLUMN public.employer.company_desc IS
  'Description of the company only: industry and purpose, from public info on the company site. Nothing about the position or the employee.';
COMMENT ON COLUMN public.employer.resume_desc IS
  'Resume text for the role: industry, role description and employee contributions. Leave null if uncertain.';
COMMENT ON COLUMN public.employer.end_title IS
  'Last title held at this employer.';
COMMENT ON COLUMN public.employer.private IS
  'True hides the row (and its titles and skill links) from resume_reader. Use for work kept off the resume.';
COMMENT ON COLUMN public.employment_titles."desc" IS
  'Resume text for this title: role description and employee contributions. Leave null if uncertain.';
COMMENT ON COLUMN public.employment_titles.bullets IS
  'Resume bullet points for this title, in display order: one contribution or fact per element. Leave null if uncertain.';
COMMENT ON COLUMN public.employment_titles.location IS
  'Work location for this title as City, ST (or region). Use remote for remote/onsite; leave null if unknown.';
COMMENT ON COLUMN public.employment_titles.remote IS
  'True if the role was remote, false if onsite; null if unknown.';
COMMENT ON COLUMN public.employment_titles.private IS
  'True hides the title (and its skill links) from resume_reader.';
COMMENT ON COLUMN public.employer_portals.w2_or_tax IS
  'True if the portal holds W-2s, pay stubs or other tax documents.';
COMMENT ON COLUMN public.employer_portals.contains_contracts IS
  'True if the portal holds signed contracts or agreements.';
COMMENT ON COLUMN public.education_and_training.remote IS
  'True if attended remotely, false if onsite; null if unknown.';
COMMENT ON COLUMN public.education_and_training.private IS
  'True hides the row (and its skill links) from resume_reader.';
COMMENT ON COLUMN public.education_and_training.gpa IS
  'GPA as a float string (e.g. 3.7), or N/A.';
COMMENT ON COLUMN public.personal_growth.private IS
  'True hides the row (and its skill links) from resume_reader.';
COMMENT ON COLUMN public.skills.type IS
  'Kind of skill (hard/soft). For display grouping use skill_group_members.';
COMMENT ON COLUMN public.skills.aliases IS
  'Other names for this skill (e.g. Node.js for Node). Matched by search_skills only; not displayed.';
COMMENT ON COLUMN public.skills.priority IS
  'User defined rankings for skill significance.';
COMMENT ON COLUMN public.skills.embedding IS
  'gte-small (384) of name + desc. Filled by edge function embed-skill via trigger.';
COMMENT ON TABLE public.skill_groups IS
  'Abstract skill buckets for resume display, e.g. "cloud services". Reuse an existing group before adding one.';
COMMENT ON COLUMN public.skill_groups.embedding IS
  'gte-small (384) of name + desc.';
COMMENT ON COLUMN public.skills.private IS
  'True hides the skill (and its links) from resume_reader.';

CREATE TABLE public.hardships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  explanation text,
  steps_taken_to_mitigate text,
  private boolean NOT NULL DEFAULT false
);
COMMENT ON TABLE public.hardships IS
  'Hardships faced and how they were mitigated.';
COMMENT ON COLUMN public.hardships.private IS
  'True hides the row from resume_reader and chat.';

-- Sort keys without exposing priority values. Owner-run so readers need no column access.
CREATE OR REPLACE FUNCTION public.skill_sort_keys()
RETURNS TABLE (id uuid, sort_rank bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$ SELECT s.id, dense_rank() OVER (ORDER BY s.priority NULLS LAST) FROM public.skills s; $$;
COMMENT ON FUNCTION public.skill_sort_keys() IS
  'Rank of each skill by priority (1 first, null last). Lets readers sort without seeing priority.';

-- ---------------------------------------------------------------------------
-- Pitches: user-written guidance for producing job-specific material
-- ---------------------------------------------------------------------------
CREATE TABLE public.pitches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  type public.pitch_type NOT NULL,
  title text NOT NULL,
  use_when varchar(300) NOT NULL,
  material text NOT NULL,
  keywords text[] NOT NULL DEFAULT '{}'
);

CREATE OR REPLACE FUNCTION public.get_all_pitches()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'slug', p.slug,
      'type', p.type,
      'title', p.title,
      'use_when', p.use_when))
    ORDER BY p.type, p.slug), '[]'::jsonb)
  FROM public.pitches p;
$$;

CREATE OR REPLACE FUNCTION public.get_pitches(p_slugs text[])
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'slug', p.slug,
      'type', p.type,
      'title', p.title,
      'use_when', p.use_when,
      'material', p.material,
      'keywords', to_jsonb(nullif(p.keywords, '{}'))))
    ORDER BY p.type, p.slug), '[]'::jsonb)
  FROM public.pitches p
  WHERE p.slug = ANY (p_slugs);
$$;

COMMENT ON TABLE public.pitches IS
  'Select pitches that fit the job post; write the output from them.';
COMMENT ON COLUMN public.pitches.slug IS
  'Cite the slugs used in each output.';
COMMENT ON COLUMN public.pitches.use_when IS
  'Used for choosing pitches for a job post.';
COMMENT ON COLUMN public.pitches.material IS
  'Primary source for generated text. Adapt it to the job post; add no claims beyond it and the evidence.';
COMMENT ON COLUMN public.pitches.keywords IS
  'Used for finding appropriate pitches.';
COMMENT ON FUNCTION public.get_all_pitches() IS
  'Used for choosing pitches for a job post. Then pitch_detail(slugs, mode) for the picked ones.';
COMMENT ON FUNCTION public.get_pitches(text[]) IS
  'Pitch text for the given slugs, without skills or evidence. Use pitch_detail for those.';

-- ---------------------------------------------------------------------------
-- Projects: portfolio work, linked to skills and growth
-- ---------------------------------------------------------------------------
CREATE TABLE public.projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(100) NOT NULL,
  "desc" text,
  start_day integer,
  start_month integer,
  start_year integer,
  end_day integer,
  end_month integer,
  end_year integer,
  priority double precision,
  -- intentional break of 3rd normal
  problem_to_solve text[] NOT NULL DEFAULT '{}',
  objective text[] NOT NULL DEFAULT '{}',
  result text[] NOT NULL DEFAULT '{}',
  brag_detail text[] NOT NULL DEFAULT '{}',
  key_features text[] NOT NULL DEFAULT '{}',
  tools_used text[] NOT NULL DEFAULT '{}',
  image_urls text[] NOT NULL DEFAULT '{}',
  live_url text[] NOT NULL DEFAULT '{}',
  source_url text[] NOT NULL DEFAULT '{}',
  -- end intentional break of 3rd normal
  private boolean NOT NULL DEFAULT false,
  vibe_and_test boolean NOT NULL DEFAULT false,
  curated_generated_code boolean NOT NULL DEFAULT false,
  hand_written_code boolean NOT NULL DEFAULT false,
  homepage_url text
);

CREATE OR REPLACE FUNCTION public.project_sort_keys()
RETURNS TABLE (id uuid, sort_rank bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$ SELECT p.id, dense_rank() OVER (ORDER BY p.priority DESC NULLS LAST) FROM public.projects p; $$;
COMMENT ON FUNCTION public.project_sort_keys() IS
  'Rank of each project by priority (higher first, null last). Lets readers sort without seeing priority.';

CREATE OR REPLACE FUNCTION public.get_projects()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'name', p.name,
      'desc', p."desc",
      'start_day', p.start_day,
      'start_month', p.start_month,
      'start_year', p.start_year,
      'end_day', p.end_day,
      'end_month', p.end_month,
      'end_year', p.end_year,
      'problem_to_solve', to_jsonb(nullif(p.problem_to_solve, '{}')),
      'objective', to_jsonb(nullif(p.objective, '{}')),
      'result', to_jsonb(nullif(p.result, '{}')),
      'brag_detail', to_jsonb(nullif(p.brag_detail, '{}')),
      'key_features', to_jsonb(nullif(p.key_features, '{}')),
      'tools_used', to_jsonb(nullif(p.tools_used, '{}')),
      'image_urls', to_jsonb(nullif(p.image_urls, '{}')),
      'live_url', to_jsonb(nullif(p.live_url, '{}')),
      'source_url', to_jsonb(nullif(p.source_url, '{}'))))
    ORDER BY k.sort_rank,
      p.start_year DESC NULLS LAST, p.start_month DESC NULLS LAST, p.start_day DESC NULLS LAST,
      p.name), '[]'::jsonb)
  FROM public.projects p
  JOIN public.project_sort_keys() k ON k.id = p.id;
$$;

COMMENT ON TABLE public.projects IS
  'Portfolio projects. Read: get_projects().';
COMMENT ON COLUMN public.projects.priority IS
  'Display order: higher first, null last. Ties fall back to newest start date.';
COMMENT ON COLUMN public.projects.private IS
  'True hides the row (and its skill/growth links) from resume_reader.';
COMMENT ON COLUMN public.projects.objective IS
  'Abstract goals for project.';
COMMENT ON COLUMN public.projects.brag_detail IS
  'Project details to brag about.';
COMMENT ON FUNCTION public.get_projects() IS
  'All visible projects as a jsonb array, ordered by name.';

