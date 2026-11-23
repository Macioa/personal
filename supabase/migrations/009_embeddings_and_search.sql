-- Embeddings and fuzzy search: search functions, embed triggers, vector/fts indexes.
-- Embedding columns stay on their tables (skills, skill_groups, transcript_chunks).
-- vector type: 1_config_and_extensions.sql.

-- ---------------------------------------------------------------------------
-- Skills: fuzzy search + embedding trigger
-- ---------------------------------------------------------------------------
-- Per term: the skill (exact name, else name part, else alias, else normalized name, else nearest by embedding) and its groups
-- (or nearest groups if no skill), with years. Group years exclude the skill.
-- Skill and group years use the matched skill's preferred_measure unless p_skill_mode / p_group_mode
-- is given (then that mode for all terms). No matched skill: start_to_end.
CREATE OR REPLACE FUNCTION public.search_skills(
  p_skills text[],
  p_embeddings extensions.vector(384)[] DEFAULT NULL,
  p_skill_mode public.skill_usage_mode DEFAULT NULL,
  p_group_mode public.skill_usage_mode DEFAULT NULL,
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
      -- Term equals one part of a combined name ("Typescript/Javascript", "Node, Express").
      (SELECT s.id FROM public.skills s
       WHERE lower(t.term) = ANY (SELECT btrim(x) FROM regexp_split_to_table(lower(s.name), '[/,&+]|\s+and\s+') x)
       LIMIT 1),
      -- Alias ("GCP" for "Google Cloud").
      (SELECT s.id FROM public.skills s
       WHERE lower(t.term) = ANY (SELECT lower(a) FROM unnest(s.aliases) a)
       LIMIT 1),
      -- Punctuation/space-insensitive ("Node.js" = "NodeJS", "CI/CD" = "CICD").
      (SELECT s.id FROM public.skills s
       WHERE regexp_replace(lower(s.name), '[^a-z0-9+#]', '', 'g')
           = regexp_replace(lower(t.term), '[^a-z0-9+#]', '', 'g')
       LIMIT 1),
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
    CROSS JOIN LATERAL public.skill_group_summary(c.group_id, mt.skill_id,
      coalesce(p_group_mode,
               (SELECT s.preferred_measure FROM public.skills s WHERE s.id = mt.skill_id),
               'start_to_end')) gs
    WHERE gs.yrs IS NOT NULL
  ),
  results AS (
    SELECT mt.term_no, mt.term, s.name AS skill, u.total_years AS yrs,
      (SELECT jsonb_agg(jsonb_build_object('name', g.name, 'yrs', g.yrs, 'examples', to_jsonb(g.examples))
                        ORDER BY g.dist, g.yrs DESC)
       FROM group_stats g WHERE g.term_no = mt.term_no) AS groups
    FROM matched mt
    LEFT JOIN public.skills s ON s.id = mt.skill_id
    LEFT JOIN LATERAL public.skill_usage(ARRAY[mt.skill_id], coalesce(p_skill_mode, s.preferred_measure)) u ON mt.skill_id IS NOT NULL
  )
  -- Label from groups (single ordering): "AWS (2) + Other cloud services (GCP, total 4)".
  -- No matching skill: the search term with 0 years, e.g. "Azure (0) + Other cloud services (...)".
  SELECT jsonb_strip_nulls(jsonb_build_object(
    'term', r.term,
    'skill', r.skill,
    'yrs', r.yrs,
    'groups', r.groups,
    'label', coalesce(r.skill || coalesce(' (' || r.yrs || ' yrs)', ''), r.term || ' (0 yrs)')
      || coalesce((
        SELECT string_agg(' + Other ' || (g.grp->>'name') || ' ('
                 || (SELECT string_agg(e.ex, ', ' ORDER BY e.ex_no)
                     FROM jsonb_array_elements_text(g.grp->'examples') WITH ORDINALITY e(ex, ex_no))
                 || ', total ' || (g.grp->>'yrs') || ' yrs)', '' ORDER BY g.grp_no)
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
    -- embed-skill runs verify_jwt: send the legacy anon JWT kept in Vault.
    headers := jsonb_build_object('Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'embed_skill_jwt')));
  RETURN NEW;
END;
$$;

CREATE TRIGGER skills_embed_trg
  AFTER INSERT OR UPDATE OF name, "desc" ON public.skills
  FOR EACH ROW EXECUTE FUNCTION public.request_skill_embedding();
CREATE TRIGGER skill_groups_embed_trg
  AFTER INSERT OR UPDATE OF name, "desc" ON public.skill_groups
  FOR EACH ROW EXECUTE FUNCTION public.request_skill_embedding();

-- ---------------------------------------------------------------------------
-- Transcripts: chunk header + hybrid search
-- ---------------------------------------------------------------------------
-- Chunk header for a backup. DEFINER so transcriber needn't read applications.
CREATE FUNCTION public.transcript_context(p_backup_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT concat_ws(' · ',
    coalesce(c.type::text, i.type::text || ' interview'),
    a.recruiting_agency, a.company, a.position,
    to_char(coalesce(c.occurred_at, i.scheduled_at, b.recorded_at), 'YYYY-MM-DD'))
  FROM public.backups b
  JOIN public.backup_sources s ON s.backup_id = b.id
  LEFT JOIN public.application_conversations c ON c.id = s.application_conversation_id
  LEFT JOIN public.application_interviews i ON i.id = s.interview_id
  JOIN public.applications a ON a.id = coalesce(c.application_id, i.application_id)
  WHERE b.id = p_backup_id;
$$;
COMMENT ON FUNCTION public.transcript_context(uuid) IS 'Chunk header for a backup.';

-- Hybrid search: reciprocal rank fusion (k=60) of cosine top-50 and full-text
-- top-50. Null embedding = keyword only (SQL-only MCP clients).
CREATE FUNCTION public.search_transcripts(
  p_query text,
  p_embedding extensions.vector(768) DEFAULT NULL,
  p_limit integer DEFAULT 8,
  p_speaker text DEFAULT NULL,
  p_backup_ids uuid[] DEFAULT NULL
)
RETURNS TABLE (
  transcript_id uuid,
  chunk_no integer,
  start_s numeric,
  end_s numeric,
  context_header text,
  content text,
  backup_url text,
  score double precision
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  WITH scope AS (
    SELECT c.transcript_id, c.chunk_no
    FROM public.transcript_chunks c
    JOIN public.backup_transcripts bt ON bt.transcript_id = c.transcript_id
    WHERE (p_backup_ids IS NULL OR bt.backup_id = ANY (p_backup_ids))
      AND (p_speaker IS NULL OR EXISTS (
        SELECT 1 FROM public.transcript_speakers s
        WHERE s.transcript_id = c.transcript_id
          AND s.speaker_no = ANY (c.speaker_nos)
          AND s.label ILIKE '%' || p_speaker || '%'))
  ), vec AS (
    SELECT c.transcript_id, c.chunk_no,
      row_number() OVER (ORDER BY c.embedding OPERATOR(extensions.<=>) p_embedding) AS r
    FROM public.transcript_chunks c
    JOIN scope USING (transcript_id, chunk_no)
    WHERE p_embedding IS NOT NULL
    ORDER BY c.embedding OPERATOR(extensions.<=>) p_embedding
    LIMIT 50
  ), kw AS (
    SELECT c.transcript_id, c.chunk_no,
      row_number() OVER (ORDER BY ts_rank_cd(c.fts, q) DESC) AS r
    FROM public.transcript_chunks c
    JOIN scope USING (transcript_id, chunk_no),
      websearch_to_tsquery('english'::regconfig, coalesce(p_query, '')) q
    WHERE c.fts @@ q
    ORDER BY ts_rank_cd(c.fts, q) DESC
    LIMIT 50
  ), fused AS (
    SELECT x.transcript_id, x.chunk_no, sum(1.0 / (60 + x.r))::double precision AS score
    FROM (SELECT * FROM vec UNION ALL SELECT * FROM kw) x
    GROUP BY x.transcript_id, x.chunk_no
  )
  SELECT c.transcript_id, c.chunk_no, c.start_s, c.end_s,
    t.context_header::text, c.content, b.backup_url, f.score
  FROM fused f
  JOIN public.transcript_chunks c ON c.transcript_id = f.transcript_id AND c.chunk_no = f.chunk_no
  JOIN public.transcripts t ON t.id = c.transcript_id
  JOIN public.backup_transcripts bt ON bt.transcript_id = c.transcript_id
  JOIN public.backups b ON b.id = bt.backup_id
  ORDER BY f.score DESC
  LIMIT p_limit;
$$;
COMMENT ON FUNCTION public.search_transcripts(text, extensions.vector, integer, text, uuid[]) IS
  'Search call transcripts. Embedding optional (keyword only without).';

-- ---------------------------------------------------------------------------
-- Indexes: vector (hnsw) and full-text
-- ---------------------------------------------------------------------------
-- search_skills() vector legs (cosine).
CREATE INDEX skills_embedding_idx
  ON public.skills USING hnsw (embedding extensions.vector_cosine_ops);
CREATE INDEX skill_groups_embedding_idx
  ON public.skill_groups USING hnsw (embedding extensions.vector_cosine_ops);

-- search_transcripts() vector leg (cosine).
CREATE INDEX transcript_chunks_embedding_idx
  ON public.transcript_chunks USING hnsw (embedding extensions.vector_cosine_ops);

-- search_transcripts() keyword leg.
CREATE INDEX transcript_chunks_fts_idx
  ON public.transcript_chunks USING gin (fts);
