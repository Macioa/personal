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
      coalesce(t.start_year, ed.start_year, g.start_year) AS sy,
      coalesce(t.start_month, ed.start_month, g.start_month) AS sm,
      coalesce(t.start_day, ed.start_day, g.start_day) AS sd,
      coalesce(t.end_year, ed.end_year, g.end_year) AS ey,
      coalesce(t.end_month, ed.end_month, g.end_month) AS em,
      coalesce(t.end_day, ed.end_day, g.end_day) AS endd
    FROM public.skill_links l
    LEFT JOIN public.employment_titles t ON t.id = l.employment_title_id
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
        'employer', te.name,
        'title', t.name,
        'edu', d.name,
        'from', coalesce(t.start_year, d.start_year),
        'to', coalesce(t.end_year, d.end_year),
        'dsc', coalesce(b.text, t."desc", d.desc_long),
        'note', pe.note)))
      FROM public.pitch_evidence pe
      LEFT JOIN public.employment_resumedesc_bullets b ON b.id = pe.employment_resumedesc_bullet_id
      LEFT JOIN public.employment_titles t ON t.id = coalesce(pe.employment_title_id, b.employment_title_id)
      LEFT JOIN public.employer te ON te.id = t.employer_id
      LEFT JOIN public.education_and_training d ON d.id = pe.education_and_training_id
      WHERE pe.pitch_id = p.id), '[]'::jsonb)
    || coalesce((SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'growth', gr.name,
        'from', CASE WHEN lp.id IS NULL THEN gr.start_year ELSE lp.start_year END,
        'to', CASE WHEN lp.id IS NULL THEN gr.end_year ELSE lp.end_year END,
        'dsc', CASE WHEN lp.id IS NULL THEN gr.desc_long ELSE lp."desc" END)))
      FROM public.pitch_growth pg
      JOIN public.personal_growth gr ON gr.id = pg.personal_growth_id
      LEFT JOIN public.project_growth pl ON pl.personal_growth_id = gr.id AND gr.include_in_resume
      LEFT JOIN public.projects lp ON lp.id = pl.project_id
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
      'lessons_learned', to_jsonb(nullif(p.lessons_learned, '{}')),
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

CREATE OR REPLACE FUNCTION public.check_growth_project_link(p_growth_id uuid)
RETURNS void LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE g public.personal_growth; n integer;
BEGIN
  SELECT * INTO g FROM public.personal_growth WHERE id = p_growth_id;
  IF NOT FOUND OR NOT g.include_in_resume THEN RETURN; END IF;
  SELECT count(*) INTO n FROM public.project_growth WHERE personal_growth_id = p_growth_id;
  IF n = 0 THEN RETURN; END IF;
  IF n > 1 THEN RAISE EXCEPTION 'Resume growth row % can link to only one project', p_growth_id; END IF;
  IF num_nonnulls(g.url, g.desc_short, g.desc_long, g.start_day, g.start_month, g.start_year,
                  g.end_day, g.end_month, g.end_year) > 0
     OR EXISTS (SELECT 1 FROM public.skill_links WHERE personal_growth_id = p_growth_id) THEN
    RAISE EXCEPTION 'Resume growth row % must take url, descriptions, dates and skills from its project', p_growth_id;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.guard_growth_project_link()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  PERFORM public.check_growth_project_link(
    (to_jsonb(NEW) ->> CASE WHEN TG_TABLE_NAME = 'personal_growth' THEN 'id' ELSE 'personal_growth_id' END)::uuid);
  RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER personal_growth_project_link_trg
  AFTER INSERT OR UPDATE ON public.personal_growth
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.guard_growth_project_link();
CREATE CONSTRAINT TRIGGER project_growth_link_trg
  AFTER INSERT OR UPDATE ON public.project_growth
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.guard_growth_project_link();
CREATE CONSTRAINT TRIGGER skill_links_growth_link_trg
  AFTER INSERT OR UPDATE ON public.skill_links
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.guard_growth_project_link();

CREATE OR REPLACE FUNCTION public.jsonb_compact(j jsonb)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE jsonb_typeof(j)
    WHEN 'object' THEN (SELECT nullif(coalesce(jsonb_object_agg(k, c), '{}'), '{}')
      FROM (SELECT k, public.jsonb_compact(v) c FROM jsonb_each(j) e(k, v)) x WHERE c IS NOT NULL)
    WHEN 'array' THEN (SELECT nullif(coalesce(jsonb_agg(c ORDER BY n), '[]'), '[]')
      FROM (SELECT n, public.jsonb_compact(v) c FROM jsonb_array_elements(j) WITH ORDINALITY a(v, n)) x WHERE c IS NOT NULL)
    WHEN 'null' THEN NULL
    ELSE j END
$$;

CREATE OR REPLACE FUNCTION public.resume_dates(sm integer, sy integer, em integer, ey integer)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  WITH v AS (SELECT CASE WHEN sy IS NOT NULL THEN concat_ws('/', sm, sy) END s,
                    CASE WHEN ey IS NOT NULL THEN concat_ws('/', em, ey) END e)
  SELECT CASE WHEN s IS NULL THEN e
              WHEN e IS NULL THEN s || '-present'
              WHEN s = e THEN s
              ELSE s || '-' || e END FROM v
$$;

CREATE OR REPLACE VIEW public.resume WITH (security_invoker = true) AS
 WITH sk AS (
         SELECT s.id,
            s.name,
            ss.sort_rank
           FROM skills s
             LEFT JOIN skill_sort_keys() ss(id, sort_rank) ON ss.id = s.id
        ), edu AS (
         SELECT d.type,
            jsonb_agg(
                CASE
                    WHEN d.type = ANY (ARRAY['bachelors'::education_type, 'masters'::education_type, 'phd'::education_type]) THEN jsonb_build_object('name', d.name, 'website', d.website, 'desc_short', d.desc_short, 'dates', resume_dates(d.start_month, d.start_year, d.end_month, d.end_year))
                    ELSE jsonb_build_object('name', d.name, 'website', d.website, 'desc_short', d.desc_short, 'dates', resume_dates(d.start_month, d.start_year, d.end_month, d.end_year), 'skills', ( SELECT jsonb_agg(sk.name ORDER BY sk.sort_rank) AS jsonb_agg
                       FROM skill_links l
                         JOIN sk ON sk.id = l.skill_id
                      WHERE l.education_and_training_id = d.id))
                END ORDER BY d.end_year DESC, d.start_year DESC) AS rows
           FROM education_and_training d
          WHERE d.type <> 'high_school'::education_type
          GROUP BY d.type
        )
 SELECT jsonb_compact(( SELECT jsonb_agg(to_jsonb(c.*) ORDER BY c.name) AS jsonb_agg
           FROM public_contact_info c)) AS intro,
    jsonb_compact(( SELECT jsonb_agg(jsonb_build_object('slug', p.slug, 'type', p.type, 'title', p.title, 'use_when', p.use_when, 'material', p.material, 'keywords', p.keywords, 'evidence', jsonb_build_object('employers', ( SELECT jsonb_agg(DISTINCT e.name) AS jsonb_agg
                   FROM pitch_evidence pe
                     LEFT JOIN employment_resumedesc_bullets b ON b.id = pe.employment_resumedesc_bullet_id
                     JOIN employment_titles t ON t.id = COALESCE(pe.employment_title_id, b.employment_title_id)
                     JOIN employer e ON e.id = t.employer_id
                  WHERE pe.pitch_id = p.id), 'education_and_training', ( SELECT jsonb_agg(DISTINCT d.name) AS jsonb_agg
                   FROM pitch_evidence pe
                     JOIN education_and_training d ON d.id = pe.education_and_training_id
                  WHERE pe.pitch_id = p.id))) ORDER BY p.slug) AS jsonb_agg
           FROM pitches p)) AS pitches,
    jsonb_compact(( SELECT jsonb_agg(jsonb_build_object('name', e.name, 'website', e.website, 'resume_desc', ( SELECT t."desc"
                   FROM employment_titles t
                  WHERE t.employer_id = e.id
                  ORDER BY t.start_year DESC NULLS LAST, t.start_month DESC NULLS LAST
                 LIMIT 1), 'last_title', ( SELECT t.name
                   FROM employment_titles t
                  WHERE t.employer_id = e.id
                  ORDER BY t.start_year DESC NULLS LAST, t.start_month DESC NULLS LAST
                 LIMIT 1), 'dates', resume_dates(e.start_month, e.start_year, e.end_month, e.end_year), 'location', ( SELECT t.location
                   FROM employment_titles t
                  WHERE t.employer_id = e.id
                  ORDER BY t.start_year DESC NULLS LAST, t.start_month DESC NULLS LAST
                 LIMIT 1), 'remote', ( SELECT t.remote
                   FROM employment_titles t
                  WHERE t.employer_id = e.id
                  ORDER BY t.start_year DESC NULLS LAST, t.start_month DESC NULLS LAST
                 LIMIT 1), 'bullets', ( SELECT jsonb_agg(b.text ORDER BY t.start_year DESC NULLS LAST, t.start_month DESC NULLS LAST, b.priority DESC NULLS LAST, b.id) AS jsonb_agg
                   FROM employment_titles t
                     JOIN employment_resumedesc_bullets b ON b.employment_title_id = t.id
                  WHERE t.employer_id = e.id), 'bullet_links', ( SELECT jsonb_object_agg(b.text, b.evidence_link) AS jsonb_object_agg
                   FROM employment_titles t
                     JOIN employment_resumedesc_bullets b ON b.employment_title_id = t.id
                  WHERE t.employer_id = e.id AND b.evidence_link IS NOT NULL), 'skills', ( SELECT jsonb_agg(x.name ORDER BY x.sort_rank) AS jsonb_agg
                   FROM ( SELECT DISTINCT sk.name,
                            sk.sort_rank
                           FROM skill_links l
                             JOIN sk ON sk.id = l.skill_id
                             JOIN employment_titles t ON t.id = l.employment_title_id
                          WHERE t.employer_id = e.id) x)) ORDER BY e.end_year DESC, e.end_month DESC, e.start_year DESC) AS jsonb_agg
           FROM employer e)) AS employment,
    jsonb_compact(( SELECT jsonb_object_agg(edu.type, edu.rows ORDER BY edu.type) AS jsonb_object_agg
           FROM edu)) AS education,
    jsonb_compact(( SELECT jsonb_agg(jsonb_build_object('name', pr.name, 'desc', pr."desc", 'homepage_url', pr.homepage_url, 'tools_used', ( SELECT jsonb_agg(tu.v ORDER BY tu.n) AS jsonb_agg
                   FROM unnest(pr.tools_used) WITH ORDINALITY tu(v, n)
                  WHERE NOT (EXISTS ( SELECT 1
                           FROM project_skills ps2
                             JOIN sk sk2 ON sk2.id = ps2.skill_id
                          WHERE ps2.project_id = pr.id AND lower(sk2.name) = lower(tu.v)))), 'dates', resume_dates(pr.start_month, pr.start_year, pr.end_month, pr.end_year), 'skills', ( SELECT jsonb_agg(sk.name ORDER BY sk.sort_rank) AS jsonb_agg
                   FROM project_skills ps
                     JOIN sk ON sk.id = ps.skill_id
                  WHERE ps.project_id = pr.id)) ORDER BY k.sort_rank) AS jsonb_agg
           FROM projects pr
             LEFT JOIN project_sort_keys() k(id, sort_rank) ON k.id = pr.id)) AS projects,
    jsonb_compact(( SELECT jsonb_agg(jsonb_build_object('name', g.name, 'desc_short', g.desc_short, 'url', g.url, 'dates', resume_dates(g.start_month, g.start_year, g.end_month, g.end_year), 'skills', ( SELECT jsonb_agg(sk.name ORDER BY sk.sort_rank) AS jsonb_agg
                   FROM skill_links l
                     JOIN sk ON sk.id = l.skill_id
                  WHERE l.personal_growth_id = g.id)) ORDER BY g.end_year DESC, g.start_year DESC) AS jsonb_agg
           FROM personal_growth g)) AS personal_growth,
    jsonb_compact(( SELECT jsonb_agg(jsonb_build_object('name', g.name, 'website', CASE WHEN p.id IS NULL THEN g.url ELSE p.homepage_url END, 'last_title', g.resume_title, 'resume_desc', CASE WHEN p.id IS NULL THEN g.desc_short ELSE p."desc" END, 'dates', CASE WHEN p.id IS NULL THEN resume_dates(g.start_month, g.start_year, g.end_month, g.end_year) ELSE resume_dates(p.start_month, p.start_year, p.end_month, p.end_year) END, 'skills', CASE WHEN p.id IS NULL THEN ( SELECT jsonb_agg(sk.name ORDER BY sk.sort_rank) AS jsonb_agg
                   FROM skill_links l
                     JOIN sk ON sk.id = l.skill_id
                  WHERE l.personal_growth_id = g.id) ELSE ( SELECT jsonb_agg(sk.name ORDER BY sk.sort_rank) AS jsonb_agg
                   FROM project_skills ps
                     JOIN sk ON sk.id = ps.skill_id
                  WHERE ps.project_id = p.id) END) ORDER BY COALESCE(p.end_year, g.end_year) DESC, COALESCE(p.end_month, g.end_month) DESC, COALESCE(p.start_year, g.start_year) DESC) AS jsonb_agg
           FROM personal_growth g
             LEFT JOIN project_growth pl ON pl.personal_growth_id = g.id
             LEFT JOIN projects p ON p.id = pl.project_id
          WHERE g.include_in_resume AND COALESCE(p.start_year, g.start_year) IS NOT NULL)) AS growth_history;
