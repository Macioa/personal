-- Resume functions and views. After 7_join_tables.sql: some read join tables.

-- Sort keys without exposing priority values. Owner-run so readers need no column access.
CREATE OR REPLACE FUNCTION public.skill_sort_keys()
RETURNS TABLE (id uuid, sort_rank bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$ SELECT s.id, dense_rank() OVER (ORDER BY s.priority NULLS LAST) FROM public.skills s; $$;
COMMENT ON FUNCTION public.skill_sort_keys() IS
  'Rank of each skill by priority (1 first, null last). Lets readers sort without seeing priority.';

-- Usage spans come from the linked row's dates (skill_links and project_skills). Missing start parts default to
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
    UNION ALL
    SELECT p.start_year, p.start_month, p.start_day, p.end_year, p.end_month, p.end_day
    FROM public.project_skills ps
    JOIN public.projects p ON p.id = ps.project_id
    WHERE ps.skill_id = ANY (p_skill_ids)
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

CREATE OR REPLACE FUNCTION public.get_all_skills()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'msg', 'in order',
    'res', coalesce(jsonb_agg(g->'name'
      ORDER BY k.sort_rank,
        (g->>'total_years')::integer DESC NULLS LAST,
        (g->>'last_used')::integer DESC NULLS LAST,
        g->>'name'), '[]'::jsonb))
  FROM public.skills s
  JOIN public.skill_sort_keys() k ON k.id = s.id
  CROSS JOIN LATERAL public.get_skill(s.name) AS g;
$$;

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

COMMENT ON VIEW public.pitch_catalog IS
  e'Used for finding appropriate pitches.
@graphql({"primary_key_columns": ["slug"], "foreign_keys": [{"local_name": "pitchCatalog", "local_columns": ["slug"], "foreign_name": "pitch", "foreign_schema": "public", "foreign_table": "pitches", "foreign_columns": ["slug"]}]})';
COMMENT ON FUNCTION public.pitch_detail(text[], public.skill_usage_mode) IS
  'Read for selected pitches before writing. p_mode sets skill durations; one mode per output.';

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

COMMENT ON FUNCTION public.get_all_pitches() IS
  'Used for choosing pitches for a job post. Then pitch_detail(slugs, mode) for the picked ones.';
COMMENT ON FUNCTION public.get_pitches(text[]) IS
  'Pitch text for the given slugs, without skills or evidence. Use pitch_detail for those.';

CREATE OR REPLACE FUNCTION public.project_sort_keys()
RETURNS TABLE (id uuid, sort_rank bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$ SELECT p.id, dense_rank() OVER (ORDER BY p.priority DESC NULLS LAST) FROM public.projects p; $$;
COMMENT ON FUNCTION public.project_sort_keys() IS
  'Rank of each project by priority (higher first, null last). Lets readers sort without seeing priority.';

-- Public portfolio content: anon may call it (012), so the site reads projects without minting a JWT.
-- SECURITY DEFINER so callers need no table grant; NOT private stands in for the RLS select policy,
-- and only the listed fields leave (priority, private and id stay hidden).
CREATE OR REPLACE FUNCTION public.get_projects()
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER SET search_path = ''
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
      'source_url', to_jsonb(nullif(p.source_url, '{}')),
      'vibe_and_test', p.vibe_and_test,
      'curated_generated_code', p.curated_generated_code,
      'hand_written_code', p.hand_written_code))
    ORDER BY k.sort_rank,
      p.start_year DESC NULLS LAST, p.start_month DESC NULLS LAST, p.start_day DESC NULLS LAST,
      p.name), '[]'::jsonb)
  FROM public.projects p
  JOIN public.project_sort_keys() k ON k.id = p.id
  WHERE NOT p.private;
$$;

COMMENT ON FUNCTION public.get_projects() IS
  'All non-private projects as a jsonb array, by priority then newest start. Public: callable by anon.';
