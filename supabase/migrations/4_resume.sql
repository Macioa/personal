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
  embedding extensions.vector(384)
);

CREATE TABLE public.skill_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  "desc" text,
  embedding extensions.vector(384)
);

CREATE TABLE public.skill_group_members (
  skill_id uuid NOT NULL REFERENCES public.skills (id) ON DELETE CASCADE,
  group_id uuid NOT NULL REFERENCES public.skill_groups (id) ON DELETE CASCADE,
  PRIMARY KEY (skill_id, group_id)
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
    CONSTRAINT education_and_training_gpa_chk CHECK (gpa = 'N/A' OR gpa ~ '^[0-9]+(\.[0-9]+)?$')
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
COMMENT ON COLUMN public.education_and_training.gpa IS
  'GPA as a float string (e.g. 3.7), or N/A.';
COMMENT ON COLUMN public.personal_growth.private IS
  'True hides the row (and its skill links) from resume_reader.';
COMMENT ON COLUMN public.skills.type IS
  'Kind of skill (hard/soft). For display grouping use skill_group_members.';
COMMENT ON COLUMN public.skills.priority IS
  'User defined rankings for skill significance.';
COMMENT ON COLUMN public.skills.embedding IS
  'gte-small (384) of name + desc. Filled by edge function embed-skill via trigger.';
COMMENT ON TABLE public.skill_groups IS
  'Abstract skill buckets for resume display, e.g. "cloud services". Reuse an existing group before adding one.';
COMMENT ON COLUMN public.skill_groups.embedding IS
  'gte-small (384) of name + desc.';
COMMENT ON TABLE public.skill_group_members IS
  'Join: skills to groups (many-to-many).';
COMMENT ON COLUMN public.skills.private IS
  'True hides the skill (and its links) from resume_reader.';
COMMENT ON COLUMN public.skill_links.private IS
  'True hides this link from resume_reader, so it is left out of skill totals.';

-- Usage spans come from the linked row's dates. Missing start parts default to
-- Jan 1; missing end parts default to the last day of the year/month; a null
-- end_year means ongoing (today). Spans of all given skills are unioned with
-- overlaps merged. precise = merged days; start_to_end = last_used -
-- first_used. total_years = those days in years, rounded up.
CREATE OR REPLACE FUNCTION public.skill_usage(
  p_skill_ids uuid[],
  p_mode public.skill_usage_mode DEFAULT 'start_to_end'
) RETURNS TABLE (first_used date, last_used date, total_years integer)
LANGUAGE sql
STABLE
AS $$
  WITH raw AS (
    SELECT
      coalesce(t.start_year, e.start_year, ed.start_year, g.start_year) AS sy,
      coalesce(t.start_month, e.start_month, ed.start_month, g.start_month) AS sm,
      coalesce(t.start_day, e.start_day, ed.start_day, g.start_day) AS sd,
      coalesce(t.end_year, e.end_year, ed.end_year, g.end_year) AS ey,
      coalesce(t.end_month, e.end_month, ed.end_month, g.end_month) AS em,
      coalesce(t.end_day, e.end_day, ed.end_day, g.end_day) AS endd
    FROM public.skill_links l
    LEFT JOIN public.employment_titles t ON t.id = l.employment_title_id
    LEFT JOIN public.employer e ON e.id = l.employer_id
    LEFT JOIN public.education_and_training ed ON ed.id = l.education_and_training_id
    LEFT JOIN public.personal_growth g ON g.id = l.personal_growth_id
    WHERE l.skill_id = ANY (p_skill_ids)
  ),
  spans AS (
    SELECT make_date(sy, coalesce(sm, 1), coalesce(sd, 1)) AS s,
      CASE
        WHEN ey IS NULL THEN current_date
        WHEN em IS NOT NULL AND endd IS NOT NULL THEN make_date(ey, em, endd)
        ELSE (make_date(ey, coalesce(em, 12), 1) + interval '1 month' - interval '1 day')::date
      END AS e
    FROM raw
    WHERE sy IS NOT NULL
  ),
  ordered AS (
    SELECT s, e,
      max(e) OVER (ORDER BY s, e ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_max
    FROM spans
  ),
  grouped AS (
    SELECT s, e,
      sum(CASE WHEN prev_max IS NULL OR s > prev_max THEN 1 ELSE 0 END) OVER (ORDER BY s, e) AS grp
    FROM ordered
  ),
  merged AS (
    SELECT min(s) AS s, max(e) AS e FROM grouped GROUP BY grp
  )
  SELECT min(s), max(e),
    ceil(CASE
      WHEN p_mode = 'precise'::public.skill_usage_mode THEN sum(e - s)
      ELSE max(e) - min(s)
    END / 365.25)::integer
  FROM merged;
$$;

CREATE OR REPLACE FUNCTION public.get_skill(
  p_skill text,
  p_mode public.skill_usage_mode DEFAULT 'start_to_end'
) RETURNS SETOF jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'skill_id', sk.id,
    'name', sk.name,
    'desc', sk."desc",
    'type', sk.type,
    'groups', (SELECT jsonb_agg(g.name ORDER BY g.name)
               FROM public.skill_group_members m
               JOIN public.skill_groups g ON g.id = m.group_id
               WHERE m.skill_id = sk.id),
    'first_used', extract(year FROM u.first_used)::integer,
    'last_used', extract(year FROM u.last_used)::integer,
    'total_years', u.total_years))
  FROM public.skills sk
  CROSS JOIN LATERAL public.skill_usage(ARRAY[sk.id], p_mode) u
  WHERE lower(sk.name) = lower(p_skill);
$$;

CREATE OR REPLACE FUNCTION public.get_skills(
  p_skills text[],
  p_mode public.skill_usage_mode DEFAULT 'start_to_end'
) RETURNS SETOF jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'id', g->'skill_id',
    'nm', g->'name',
    'dsc', g->'desc',
    't', g->'type',
    'grp', g->'groups',
    'from', g->'first_used',
    'to', g->'last_used',
    'yrs', g->'total_years'))
  FROM unnest(p_skills) AS u(skill)
  CROSS JOIN LATERAL public.get_skill(u.skill, p_mode) AS g;
$$;

-- A group's other members (all but p_exclude_skill_id): merged years and top 3 by own years.
CREATE OR REPLACE FUNCTION public.skill_group_summary(
  p_group_id uuid,
  p_exclude_skill_id uuid,
  p_mode public.skill_usage_mode DEFAULT 'start_to_end'
) RETURNS TABLE (yrs integer, examples text[])
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  WITH members AS (
    SELECT s.id, s.name
    FROM public.skill_group_members m
    JOIN public.skills s ON s.id = m.skill_id
    WHERE m.group_id = p_group_id AND m.skill_id IS DISTINCT FROM p_exclude_skill_id
  )
  SELECT
    (SELECT u.total_years FROM public.skill_usage(ARRAY(SELECT id FROM members), p_mode) u),
    ARRAY(SELECT mb.name
          FROM members mb
          CROSS JOIN LATERAL public.skill_usage(ARRAY[mb.id], p_mode) u
          WHERE u.total_years IS NOT NULL
          ORDER BY u.total_years DESC, mb.name
          LIMIT 3);
$$;

-- Per term: the skill (exact name, else nearest by embedding) and its groups
-- (or nearest groups if no skill), with years. Group years exclude the skill.
-- Skill years use p_skill_mode (default precise); group years p_group_mode (default start_to_end).
CREATE OR REPLACE FUNCTION public.search_skills(
  p_skills text[],
  p_embeddings extensions.vector(384)[] DEFAULT NULL,
  p_skill_mode public.skill_usage_mode DEFAULT 'precise',
  p_group_mode public.skill_usage_mode DEFAULT 'start_to_end',
  p_group_limit integer DEFAULT 2,
  p_min_sim double precision DEFAULT 0.9,
  p_group_min_sim double precision DEFAULT 0.815
) RETURNS SETOF jsonb
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  WITH terms AS (
    SELECT t.term, t.term_no, p_embeddings[t.term_no] AS emb
    FROM unnest(p_skills) WITH ORDINALITY AS t(term, term_no)
  ),
  matched AS (
    SELECT t.*, coalesce(
      (SELECT s.id FROM public.skills s WHERE lower(s.name) = lower(t.term) LIMIT 1),
      (SELECT s.id FROM public.skills s
       WHERE t.emb IS NOT NULL AND s.embedding IS NOT NULL
         AND 1 - (s.embedding OPERATOR(extensions.<=>) t.emb) >= p_min_sim
       ORDER BY s.embedding OPERATOR(extensions.<=>) t.emb LIMIT 1)) AS skill_id
    FROM terms t
  ),
  candidate_groups AS (
    -- Explicit groups of a matched skill; else nearest groups by embedding above p_group_min_sim.
    SELECT mt.term_no, g.id AS group_id, g.name, 0::double precision AS dist
    FROM matched mt
    JOIN public.skill_group_members m ON m.skill_id = mt.skill_id
    JOIN public.skill_groups g ON g.id = m.group_id
    UNION ALL
    SELECT mt.term_no, n.id, n.name, n.dist
    FROM matched mt
    CROSS JOIN LATERAL (
      SELECT g.id, g.name, g.embedding OPERATOR(extensions.<=>) mt.emb AS dist
      FROM public.skill_groups g
      WHERE g.embedding IS NOT NULL
        AND 1 - (g.embedding OPERATOR(extensions.<=>) mt.emb) >= p_group_min_sim
      ORDER BY 3 LIMIT p_group_limit) n
    WHERE mt.skill_id IS NULL AND mt.emb IS NOT NULL
  ),
  group_stats AS (
    SELECT c.term_no, c.name, c.dist, gs.yrs, gs.examples
    FROM candidate_groups c
    JOIN matched mt ON mt.term_no = c.term_no
    CROSS JOIN LATERAL public.skill_group_summary(c.group_id, mt.skill_id, p_group_mode) gs
    WHERE gs.yrs IS NOT NULL
  ),
  results AS (
    SELECT mt.term_no, mt.term, s.name AS skill, u.total_years AS yrs,
      (SELECT jsonb_agg(jsonb_build_object('name', g.name, 'yrs', g.yrs, 'examples', to_jsonb(g.examples))
                        ORDER BY g.dist, g.yrs DESC)
       FROM group_stats g WHERE g.term_no = mt.term_no) AS groups
    FROM matched mt
    LEFT JOIN public.skills s ON s.id = mt.skill_id
    LEFT JOIN LATERAL public.skill_usage(ARRAY[mt.skill_id], p_skill_mode) u ON mt.skill_id IS NOT NULL
  )
  -- Label from groups (single ordering): "AWS (2) + Other cloud services (GCP, total 4)".
  -- No matching skill: the search term with 0 years, e.g. "Azure (0) + Other cloud services (...)".
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'term', r.term,
    'skill', r.skill,
    'yrs', r.yrs,
    'groups', r.groups,
    'label', coalesce(r.skill || coalesce(' (' || r.yrs || ')', ''), r.term || ' (0)')
      || coalesce((
        SELECT string_agg(' + Other ' || (g.grp->>'name') || ' ('
                 || (SELECT string_agg(e.ex, ', ' ORDER BY e.ex_no)
                     FROM jsonb_array_elements_text(g.grp->'examples') WITH ORDINALITY e(ex, ex_no))
                 || ', total ' || (g.grp->>'yrs') || ')', '' ORDER BY g.grp_no)
        FROM jsonb_array_elements(r.groups) WITH ORDINALITY g(grp, grp_no)), '')))
  FROM results r
  ORDER BY r.term_no;
$$;

COMMENT ON FUNCTION public.search_skills(text[], extensions.vector[], public.skill_usage_mode, public.skill_usage_mode, integer, double precision, double precision) IS
  'Skill + abstract group years, e.g. "AWS (2) + Other cloud services (4)". Embeddings optional (fuzzy match only).';

-- Async embed via edge function embed-skill (pg_net). Fires on name/desc change.
CREATE OR REPLACE FUNCTION public.request_skill_embedding()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://yxmzfpicfrlvzqogzmyl.supabase.co/functions/v1/embed-skill',
    body := jsonb_build_object('table', TG_TABLE_NAME, 'id', NEW.id),
    headers := '{"Content-Type":"application/json"}'::jsonb);
  RETURN NEW;
END;
$$;

CREATE TRIGGER skills_embed_trg
  AFTER INSERT OR UPDATE OF name, "desc" ON public.skills
  FOR EACH ROW EXECUTE FUNCTION public.request_skill_embedding();
CREATE TRIGGER skill_groups_embed_trg
  AFTER INSERT OR UPDATE OF name, "desc" ON public.skill_groups
  FOR EACH ROW EXECUTE FUNCTION public.request_skill_embedding();

CREATE OR REPLACE FUNCTION public.get_all_skills()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'msg', 'in order',
    'res', coalesce(jsonb_agg(g->'name'
      ORDER BY s.priority NULLS LAST,
        (g->>'total_years')::integer DESC NULLS LAST,
        (g->>'last_used')::integer DESC NULLS LAST,
        g->>'name'), '[]'::jsonb))
  FROM public.skills s
  CROSS JOIN LATERAL public.get_skill(s.name) AS g;
$$;

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

CREATE TABLE public.pitch_skills (
  pitch_id uuid NOT NULL REFERENCES public.pitches (id),
  skill_id uuid NOT NULL REFERENCES public.skills (id),
  PRIMARY KEY (pitch_id, skill_id)
);

-- One row links a pitch to exactly one proof: title, employer, education.
CREATE TABLE public.pitch_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pitch_id uuid NOT NULL REFERENCES public.pitches (id),
  employment_title_id uuid REFERENCES public.employment_titles (id),
  employer_id uuid REFERENCES public.employer (id),
  education_and_training_id uuid REFERENCES public.education_and_training (id),
  note varchar(300),
  CONSTRAINT pitch_evidence_exactly_one_target_chk
    CHECK (num_nonnulls(employment_title_id, employer_id, education_and_training_id) = 1)
);

CREATE TABLE public.pitch_growth (
  pitch_id uuid NOT NULL REFERENCES public.pitches (id) ON DELETE CASCADE,
  personal_growth_id uuid NOT NULL REFERENCES public.personal_growth (id) ON DELETE CASCADE,
  PRIMARY KEY (pitch_id, personal_growth_id)
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
    coalesce((SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'nm', g->'nm',
        'grp', g->'grp',
        'from', g->'from',
        'to', g->'to',
        'yrs', g->'yrs')) ORDER BY g->>'grp' NULLS LAST, g->>'nm')
      FROM public.get_skills(
        ARRAY(SELECT s.name FROM public.pitch_skills ps
              JOIN public.skills s ON s.id = ps.skill_id
              WHERE ps.pitch_id = p.id),
        p_mode) AS g), '[]'::jsonb),
    coalesce((SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'employer', coalesce(e.name, te.name),
        'title', t.name,
        'edu', d.name,
        'from', coalesce(t.start_year, e.start_year, d.start_year),
        'to', coalesce(t.end_year, e.end_year, d.end_year),
        'dsc', coalesce(t."desc", e.resume_desc, d.desc_long),
        'note', pe.note)))
      FROM public.pitch_evidence pe
      LEFT JOIN public.employment_titles t ON t.id = pe.employment_title_id
      LEFT JOIN public.employer te ON te.id = t.employer_id
      LEFT JOIN public.employer e ON e.id = pe.employer_id
      LEFT JOIN public.education_and_training d ON d.id = pe.education_and_training_id
      WHERE pe.pitch_id = p.id), '[]'::jsonb)
    || coalesce((SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'growth', gr.name,
        'from', gr.start_year,
        'to', gr.end_year,
        'dsc', gr.desc_long)))
      FROM public.pitch_growth pg
      JOIN public.personal_growth gr ON gr.id = pg.personal_growth_id
      WHERE pg.pitch_id = p.id), '[]'::jsonb)
  FROM public.pitches p
  WHERE p.slug = ANY (p_slugs);
$$;

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
COMMENT ON TABLE public.pitch_skills IS
  'Durations: get_skills(names, mode). One mode per output.';
COMMENT ON TABLE public.pitch_evidence IS
  'Join table: pitches to the work that backs them. Facts the output may state.';
COMMENT ON TABLE public.pitch_growth IS
  'Join table: pitches to personal_growth rows that back them.';
COMMENT ON COLUMN public.pitch_evidence.note IS
  'Explains how the linked row supports the pitch.';
COMMENT ON VIEW public.pitch_catalog IS
  'Used for finding appropriate pitches.';
COMMENT ON FUNCTION public.pitch_detail(text[], public.skill_usage_mode) IS
  'Read for selected pitches before writing. p_mode sets skill durations; one mode per output.';
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
  problem_to_solve text,
  objective text,
  result text,
  brag_detail text,
  -- intentional break of 3rd normal
  key_features text[] NOT NULL DEFAULT '{}',
  tools_used text[] NOT NULL DEFAULT '{}',
  -- end intentional break of 3rd normal
  live_url text,
  source_url text,
  private boolean NOT NULL DEFAULT false
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

CREATE OR REPLACE FUNCTION public.get_projects()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'name', p.name,
      'desc', p."desc",
      'problem_to_solve', p.problem_to_solve,
      'objective', p.objective,
      'result', p.result,
      'brag_detail', p.brag_detail,
      'key_features', to_jsonb(nullif(p.key_features, '{}')),
      'tools_used', to_jsonb(nullif(p.tools_used, '{}')),
      'live_url', p.live_url,
      'source_url', p.source_url))
    ORDER BY p.name), '[]'::jsonb)
  FROM public.projects p;
$$;

COMMENT ON TABLE public.projects IS
  'Portfolio projects. Read: get_projects().';
COMMENT ON COLUMN public.projects.private IS
  'True hides the row (and its skill/growth links) from resume_reader.';
COMMENT ON COLUMN public.projects.objective IS
  'Abstract goals for project.';
COMMENT ON COLUMN public.projects.brag_detail IS
  'Project details to brag about.';
COMMENT ON TABLE public.project_skills IS
  'Join table: projects to skills used.';
COMMENT ON TABLE public.project_growth IS
  'Join table: projects to personal_growth rows they came from.';
COMMENT ON TABLE public.pitch_projects IS
  'Join table: pitches to projects that back them.';
COMMENT ON FUNCTION public.get_projects() IS
  'All visible projects as a jsonb array, ordered by name.';

