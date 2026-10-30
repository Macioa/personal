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
  'clearance',
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
  end_year integer,
  private boolean NOT NULL DEFAULT false
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
  skill_group text,
  private boolean NOT NULL DEFAULT false
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
  private boolean NOT NULL DEFAULT false
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
  private boolean NOT NULL DEFAULT false,
  CONSTRAINT skill_links_exactly_one_target_chk
    CHECK (num_nonnulls(employment_title_id, employer_id, education_and_training_id, personal_growth_id) = 1)
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
COMMENT ON COLUMN public.personal_growth.private IS
  'True hides the row (and its skill links) from resume_reader.';
COMMENT ON COLUMN public.skills.type IS
  'Kind of skill (hard/soft). For display grouping use skill_group.';
COMMENT ON COLUMN public.skills.skill_group IS
  'Consolidation bucket for resume display, e.g. "Programming languages", "Web server frameworks", "Cloud platforms". Reuse an existing value (SELECT DISTINCT skill_group FROM skills) before adding one. Null = standalone skill.';
COMMENT ON COLUMN public.skills.private IS
  'True hides the skill (and its links) from resume_reader.';
COMMENT ON COLUMN public.skill_links.private IS
  'True hides this link from resume_reader, so it is left out of skill totals.';

-- Usage spans come from the linked row's dates. Missing start parts default to
-- Jan 1; missing end parts default to the last day of the year/month; a null
-- end_year means ongoing (today). precise = union of spans with overlaps
-- merged; start_to_end = last_used - first_used. total_years = those days
-- in years, rounded up.
CREATE OR REPLACE FUNCTION public.get_skill(
  p_skill text,
  p_mode public.skill_usage_mode DEFAULT 'start_to_end'
) RETURNS TABLE (
  skill_id uuid,
  name text,
  "desc" text,
  type public.skill_type,
  skill_group text,
  first_used integer,
  last_used integer,
  total_years integer
)
LANGUAGE sql
STABLE
AS $$
  WITH s AS (
    SELECT sk.id, sk.name, sk."desc", sk.type, sk.skill_group
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
  SELECT s.id, s.name, s."desc", s.type, s.skill_group,
    extract(year FROM a.first_used)::integer, extract(year FROM a.last_used)::integer,
    ceil(CASE
      WHEN p_mode = 'precise'::public.skill_usage_mode THEN a.precise_days
      ELSE (a.last_used - a.first_used)
    END / 365.25)::integer
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
  skill_group text,
  first_used integer,
  last_used integer,
  total_years integer
)
LANGUAGE sql
STABLE
AS $$
  SELECT g.*
  FROM unnest(p_skills) AS u(skill)
  CROSS JOIN LATERAL public.get_skill(u.skill, p_mode) AS g;
$$;

CREATE OR REPLACE FUNCTION public.get_all_skills()
RETURNS text[]
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(array_agg(s.name ORDER BY s.name), '{}')
  FROM public.skills s;
$$;

-- ---------------------------------------------------------------------------
-- Pitches: user-written guidance for producing job-specific material
-- ---------------------------------------------------------------------------
CREATE TYPE public.pitch_type AS ENUM (
  'technical',
  'leadership',
  'delivery',
  'domain',
  'collaboration',
  'other'
);

CREATE TABLE public.pitches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  type public.pitch_type NOT NULL,
  title text NOT NULL,
  use_when varchar(300) NOT NULL,
  material text NOT NULL,
  keywords text[] NOT NULL DEFAULT '{}'
);

CREATE TABLE public.pitch_skills (
  pitch_id uuid NOT NULL REFERENCES public.pitches (id),
  skill_id uuid NOT NULL REFERENCES public.skills (id),
  PRIMARY KEY (pitch_id, skill_id)
);

-- One row links a pitch to exactly one proof: title, employer, education, growth.
CREATE TABLE public.pitch_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pitch_id uuid NOT NULL REFERENCES public.pitches (id),
  employment_title_id uuid REFERENCES public.employment_titles (id),
  employer_id uuid REFERENCES public.employer (id),
  education_and_training_id uuid REFERENCES public.education_and_training (id),
  personal_growth_id uuid REFERENCES public.personal_growth (id),
  note varchar(300),
  CONSTRAINT pitch_evidence_exactly_one_target_chk
    CHECK (num_nonnulls(employment_title_id, employer_id, education_and_training_id, personal_growth_id) = 1)
);

CREATE VIEW public.pitch_catalog WITH (security_invoker = true) AS
SELECT p.slug, p.type, p.title, p.use_when, p.keywords,
  ARRAY(SELECT s.name FROM public.pitch_skills ps
        JOIN public.skills s ON s.id = ps.skill_id
        WHERE ps.pitch_id = p.id ORDER BY s.name) AS skills,
  (SELECT count(*) FROM public.pitch_evidence e WHERE e.pitch_id = p.id) AS evidence_count
FROM public.pitches p;

CREATE OR REPLACE FUNCTION public.pitch_detail(
  p_slugs text[],
  p_mode public.skill_usage_mode
) RETURNS TABLE (
  slug text,
  material text,
  skills jsonb,
  evidence jsonb
)
LANGUAGE sql
STABLE
AS $$
  SELECT p.slug, p.material,
    (SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'name', g.name,
        'group', g.skill_group,
        'first_used', g.first_used,
        'last_used', g.last_used,
        'total_years', g.total_years)) ORDER BY g.skill_group NULLS LAST, g.name)
      FROM public.get_skills(
        ARRAY(SELECT s.name FROM public.pitch_skills ps
              JOIN public.skills s ON s.id = ps.skill_id
              WHERE ps.pitch_id = p.id),
        p_mode) AS g),
    (SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'employer', coalesce(e.name, te.name),
        'title', t.name,
        'education', d.name,
        'growth', gr.name,
        'start_year', coalesce(t.start_year, e.start_year, d.start_year, gr.start_year),
        'end_year', coalesce(t.end_year, e.end_year, d.end_year, gr.end_year),
        'description', coalesce(t."desc", e.resume_desc, d.desc_long, gr.desc_long),
        'note', pe.note)))
      FROM public.pitch_evidence pe
      LEFT JOIN public.employment_titles t ON t.id = pe.employment_title_id
      LEFT JOIN public.employer te ON te.id = t.employer_id
      LEFT JOIN public.employer e ON e.id = pe.employer_id
      LEFT JOIN public.education_and_training d ON d.id = pe.education_and_training_id
      LEFT JOIN public.personal_growth gr ON gr.id = pe.personal_growth_id
      WHERE pe.pitch_id = p.id)
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
COMMENT ON TABLE public.pitch_skills IS
  'Durations: get_skills(names, mode). One mode per output.';
COMMENT ON TABLE public.pitch_evidence IS
  'Join table: pitches to the work that backs them. Facts the output may state.';
COMMENT ON COLUMN public.pitch_evidence.note IS
  'Explains how the linked row supports the pitch.';
COMMENT ON VIEW public.pitch_catalog IS
  'Used for finding appropriate pitches.';
COMMENT ON FUNCTION public.pitch_detail(text[], public.skill_usage_mode) IS
  'Read for selected pitches before writing. p_mode sets skill durations; one mode per output.';

