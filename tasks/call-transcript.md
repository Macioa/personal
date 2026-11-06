# Call transcript

> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

1. Fathom (connector, mcp) first.
2. Else ask for recording path and speaker count; run:
   `python scripts/transcribe/main.py <recording> [num_speakers=2] [model=small, amr large-v3-turbo] [out_dir=temp/transcripts]`
3. Outputs: `.md`, `.json`, `.archive.mp4` (compressed video).
4. Optionally ask for real names; replace `Speaker N`.
5. Log backup (Supabase MCP; show rows, get yes): `backups` row (`type`, `duration`, `backup_url`, `backup_location`, `original_format`, `backup_format`, `original_filename`, `recorded_at`; no URL given → `backup_url` = local absolute path of `.archive.mp4`) + `backup_sources` row (exactly one of `communication_id` / `interview_id`).
6. Ingest for search:
   `python scripts/vector/ingest.py temp/transcripts/<stem>.json --backup <backup id> [--self <my speaker no>] [--asr-model <model>]`
   - Labels come from the `.md`. Re-run after relabeling; it replaces the old transcript.
   - Fathom: first write its transcript as `<stem>.json` (`[{speaker, start, end, text}]`, start/end in seconds) + `<stem>.md` (`[HH:MM:SS] Label: text`, one line per turn), then add `--source fathom`.
   - Check first: `--dry-run`.
