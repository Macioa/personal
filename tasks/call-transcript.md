# Call transcript

> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

1. Fathom (connector, mcp) first.
2. Else ask for recording path and speaker count; run:
   `python scripts/transcribe/main.py <recording> [num_speakers=2] [model=small] [out_dir=temp/transcripts]`
3. Outputs: `.md`, `.json`, `.archive.mp4` (compressed video).
4. Optionally ask for real names; replace `Speaker N`.
