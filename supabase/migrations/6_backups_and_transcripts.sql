-- ---------------------------------------------------------------------------
-- Call backups + searchable transcripts. Backups link 1:1 to a communication or
-- an interview; transcripts link 1:1 to a backup and are stored as labeled turns
-- plus embedded chunks (bge-base-en-v1.5, 768 dims, computed by scripts/vector).
-- vector type: 1_config_and_extensions.sql.
--   transcript_context(backup)   chunk header: type · agency · company · position · date
--   search_transcripts(q, emb)   hybrid vector + full-text search (emb optional)
--   get_transcript_window(...)   labeled turns around a hit
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Backups
-- ---------------------------------------------------------------------------
CREATE TABLE public.backups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type public.backup_type NOT NULL,
  duration interval,
  backup_url text NOT NULL CHECK (backup_url ~* '^(https?://|[a-z]:[\\/]|/)'),  -- URL or local absolute path
  backup_location varchar(100) NOT NULL,
  original_format varchar(20) NOT NULL,
  backup_format varchar(20) NOT NULL,
  original_filename text,
  recorded_at timestamptz(0)
);
COMMENT ON TABLE public.backups IS 'Call/message recordings. Link: backup_sources, backup_transcripts.';
COMMENT ON COLUMN public.backups.backup_location IS 'Where the file lives, e.g. phonecall-backups (Drive).';
COMMENT ON COLUMN public.backups.backup_format IS 'amr (copied as-is) or mp4 (compressed archive).';

-- 1:1 backup -> exactly one communication or interview.
CREATE TABLE public.backup_sources (
  backup_id uuid PRIMARY KEY REFERENCES public.backups (id) ON DELETE CASCADE,
  communication_id uuid UNIQUE REFERENCES public.application_conversations (id) ON DELETE CASCADE,
  interview_id uuid UNIQUE REFERENCES public.application_interviews (id) ON DELETE CASCADE,
  CONSTRAINT backup_sources_one_target_chk
    CHECK (num_nonnulls(communication_id, interview_id) = 1)
);

-- ---------------------------------------------------------------------------
-- Transcripts
-- ---------------------------------------------------------------------------
CREATE TABLE public.transcripts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source public.transcript_source NOT NULL,
  asr_model varchar(50),
  word_count integer NOT NULL,
  context_header varchar(300),
  embedding_model varchar(100) NOT NULL,
  chunker_version smallint NOT NULL,
  created_at timestamptz(0) NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.transcripts IS
  'Call transcripts. Write: scripts/vector/ingest.py. Read: search_transcripts.';
COMMENT ON COLUMN public.transcripts.word_count IS
  'Words after the silence-hallucination filter. 0 = no speech, no chunks.';
COMMENT ON COLUMN public.transcripts.context_header IS
  'transcript_context() at ingest; prepended to each chunk when embedded.';

-- 1:1 backup <-> transcript.
CREATE TABLE public.backup_transcripts (
  backup_id uuid PRIMARY KEY REFERENCES public.backups (id) ON DELETE CASCADE,
  transcript_id uuid NOT NULL UNIQUE REFERENCES public.transcripts (id) ON DELETE CASCADE
);

-- Speakers are per transcript, not people in the DB.
CREATE TABLE public.transcript_speakers (
  transcript_id uuid NOT NULL REFERENCES public.transcripts (id) ON DELETE CASCADE,
  speaker_no smallint NOT NULL,
  label varchar(100) NOT NULL,
  is_self boolean NOT NULL DEFAULT false,
  PRIMARY KEY (transcript_id, speaker_no)
);
COMMENT ON COLUMN public.transcript_speakers.speaker_no IS 'Diarization number 1..N.';
COMMENT ON COLUMN public.transcript_speakers.label IS
  'Free text, not unique; may name several people (e.g. Jennifer (CRC) + Ryan).';

-- Canonical transcript: one row per kept turn.
CREATE TABLE public.transcript_turns (
  transcript_id uuid NOT NULL,
  turn_no integer NOT NULL,
  speaker_no smallint NOT NULL,
  start_s numeric(8, 2) NOT NULL,
  end_s numeric(8, 2) NOT NULL,
  text text NOT NULL,
  PRIMARY KEY (transcript_id, turn_no),
  FOREIGN KEY (transcript_id, speaker_no)
    REFERENCES public.transcript_speakers (transcript_id, speaker_no) ON DELETE CASCADE,
  CONSTRAINT transcript_turns_time_chk CHECK (end_s >= start_s)
);
COMMENT ON COLUMN public.transcript_turns.turn_no IS '0-based, after the silence-hallucination filter.';

-- Search units: overlapping windows of turns.
CREATE TABLE public.transcript_chunks (
  transcript_id uuid NOT NULL REFERENCES public.transcripts (id) ON DELETE CASCADE,
  chunk_no integer NOT NULL,
  first_turn integer NOT NULL,
  last_turn integer NOT NULL,
  start_s numeric(8, 2) NOT NULL,
  end_s numeric(8, 2) NOT NULL,
  speaker_nos smallint[] NOT NULL,
  word_count integer NOT NULL,
  content text NOT NULL,
  fts tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, content)) STORED,
  embedding extensions.vector(768) NOT NULL,
  PRIMARY KEY (transcript_id, chunk_no),
  CONSTRAINT transcript_chunks_range_chk CHECK (last_turn >= first_turn AND end_s >= start_s)
);
COMMENT ON COLUMN public.transcript_chunks.content IS
  '"Label: text" lines. Embedded as context_header + newline + content.';

-- ---------------------------------------------------------------------------
-- Functions
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
  LEFT JOIN public.application_conversations c ON c.id = s.communication_id
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

-- Labeled turns overlapping [from - pad, to + pad]. Full transcript: (id, 0, 1e6, 0).
CREATE FUNCTION public.get_transcript_window(
  p_transcript_id uuid,
  p_from_s numeric,
  p_to_s numeric,
  p_pad_s numeric DEFAULT 30
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object('turn_no', tt.turn_no, 'start_s', tt.start_s,
        'speaker', s.label, 'text', tt.text)
      ORDER BY tt.turn_no
    ),
    '[]'::jsonb
  )
  FROM public.transcript_turns tt
  JOIN public.transcript_speakers s
    ON s.transcript_id = tt.transcript_id AND s.speaker_no = tt.speaker_no
  WHERE tt.transcript_id = p_transcript_id
    AND tt.end_s >= p_from_s - p_pad_s
    AND tt.start_s <= p_to_s + p_pad_s;
$$;
COMMENT ON FUNCTION public.get_transcript_window(uuid, numeric, numeric, numeric) IS
  'Context turns around a hit.';
