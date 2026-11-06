# Search transcripts

> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

Searches call transcripts stored by `call-transcript` step 6. Schema: `supabase/migrations/6_backups_and_transcripts.sql`.

1. Semantic + keyword (preferred):
   `python scripts/vector/search.py "<question>" [--limit 8] [--speaker <label part>] [--backup <uuid> ...] [--context]`
   - `--speaker`: only chunks where that speaker talks (label `ILIKE`).
   - `--context`: also prints the turns around each hit.
2. Keyword only (Supabase MCP, no shell): `select * from search_transcripts('<words>'[, null, <limit>, '<speaker>'])`.
3. More context: `select get_transcript_window('<transcript_id>', <start_s>, <end_s>[, <pad_s>=30])`. Full transcript: `(<id>, 0, 1e6, 0)`.
4. Quote hits with their header, timestamp and `backup_url`. Don't paraphrase quotes.
