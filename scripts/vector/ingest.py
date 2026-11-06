"""Transcript JSON -> transcripts, speakers, turns, embedded chunks; linked to a backup.

Usage: python ingest.py <transcript.json> --backup <uuid> [--self N]
         [--speakers "1=Christy Hunter (HCA),2=Ryan"] [--source whisper|fathom|manual] [--asr-model M]
       python ingest.py <transcript.json> [...] --dry-run [--header H]   (no DB; chunks + token counts)
Labels: --speakers, else the sibling .md, else "Speaker N". Re-ingesting a backup replaces its transcript.
Needs env TRANSCRIBER_DB_URL (transcriber role).
"""
import argparse, json, re, sys
from pathlib import Path

import chunk, deps

SAMPLE_HEADER = "phone · Recruiting Agency Name · Company Name · Principal Software Engineer · 2026-01-01"


# CLI args
def args():
    p = argparse.ArgumentParser()
    p.add_argument("json", type=Path)
    p.add_argument("--backup")
    p.add_argument("--speakers")
    p.add_argument("--self", dest="self_no", type=int)
    p.add_argument("--source", default="whisper", choices=["whisper", "fathom", "manual"])
    p.add_argument("--asr-model")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--header", default=SAMPLE_HEADER, help="dry-run only: header used for token counts")
    a = p.parse_args()
    if not a.dry_run and not a.backup:
        p.error("--backup is required unless --dry-run")
    return a


# "1=Name A,2=Name B" -> {1: "Name A", 2: "Name B"}
def parse_speakers(s):
    return {int(k): v.strip() for k, v in (x.split("=", 1) for x in re.split(r",\s*(?=\d+=)", s))}


# speaker_no -> label for every speaker in the raw turns
def labels(raw, a):
    found = parse_speakers(a.speakers) if a.speakers else chunk.md_labels(raw, a.json.with_suffix(".md"))
    return {s: found.get(s, f"Speaker {s}") for s in sorted({t["speaker"] for t in raw})}


# Chunk header from the backup's communication/interview + application
def header(conn, backup):
    row = conn.execute("SELECT public.transcript_context(%s)", (backup,)).fetchone()
    if not row or not row[0]:
        sys.exit(f"backup {backup}: no backup_sources row (or backup missing)")
    return row[0]


# Chunks whose header + content fit the model's token limit
def chunks_for(turns, lab, head):
    import embed
    budget = embed.MAX_TOKENS - embed.tokens(head) - 2  # header line + newline
    return chunk.chunk(turns, lab, embed.tokens, budget)


# Embedded text for one chunk
def embed_text(head, c):
    return f"{head}\n{c.content}" if head else c.content


# Print chunks and token counts; no DB
def dry_run(turns, chunks, head):
    import embed
    worst = 0
    for c in chunks:
        tok = embed.tokens(embed_text(head, c))
        worst = max(worst, tok)
        flag = "  OVER" if tok > embed.MAX_TOKENS else ""
        print(f"{c.chunk_no:3} [{chunk.ts(c.start)}-{chunk.ts(c.end)}] t{c.first_turn}-{c.last_turn} "
              f"{c.words:3}w {tok:3}tok{flag}  {c.content.splitlines()[0][:80]}")
    print(f"{len(turns)} turns, {len(chunks)} chunks, max {worst} tokens")


# Replace the backup's transcript in one transaction; return transcript id
def write(conn, a, lab, turns, chunks, head, vecs):
    import embed
    with conn.transaction():
        conn.execute("""DELETE FROM public.transcripts t USING public.backup_transcripts bt
                        WHERE bt.backup_id = %s AND t.id = bt.transcript_id""", (a.backup,))
        tid = conn.execute(
            """INSERT INTO public.transcripts (source, asr_model, word_count, context_header,
                 embedding_model, chunker_version) VALUES (%s, %s, %s, %s, %s, %s) RETURNING id""",
            (a.source, a.asr_model, sum(chunk.n(t["text"]) for t in turns), head,
             embed.MODEL, chunk.VERSION)).fetchone()[0]
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO public.transcript_speakers (transcript_id, speaker_no, label, is_self) VALUES (%s, %s, %s, %s)",
                [(tid, s, l, s == a.self_no) for s, l in lab.items()])
            cur.executemany(
                "INSERT INTO public.transcript_turns (transcript_id, turn_no, speaker_no, start_s, end_s, text) VALUES (%s, %s, %s, %s, %s, %s)",
                [(tid, i, t["speaker"], round(t["start"], 2), round(t["end"], 2), t["text"].strip())
                 for i, t in enumerate(turns)])
            cur.executemany(
                """INSERT INTO public.transcript_chunks (transcript_id, chunk_no, first_turn, last_turn,
                     start_s, end_s, speaker_nos, word_count, content, embedding)
                   VALUES (%s, %s, %s, %s, %s, %s, %s::smallint[], %s, %s, %s::extensions.vector)""",
                [(tid, c.chunk_no, c.first_turn, c.last_turn, round(c.start, 2), round(c.end, 2),
                  c.speakers, c.words, c.content, embed.lit(v)) for c, v in zip(chunks, vecs)])
        conn.execute("INSERT INTO public.backup_transcripts (backup_id, transcript_id) VALUES (%s, %s)",
                     (a.backup, tid))
    return tid


# Full process: load, filter, chunk, embed, write
def main(a):
    deps.ensure_deps()
    import db, embed
    raw = json.loads(a.json.read_text(encoding="utf-8"))
    lab = labels(raw, a)
    if a.self_no is not None and a.self_no not in lab:
        sys.exit(f"--self {a.self_no}: no such speaker ({sorted(lab)})")
    turns = chunk.drop_hallucinations(raw)
    if a.dry_run:
        return dry_run(turns, chunks_for(turns, lab, a.header), a.header)
    with db.connect() as conn:
        head = header(conn, a.backup)
        chunks = chunks_for(turns, lab, head)
        vecs = embed.docs([embed_text(head, c) for c in chunks])
        tid = write(conn, a, lab, turns, chunks, head, vecs)
    print(f"transcript {tid}: {len(turns)} turns, {len(chunks)} chunks, header {head!r}")


if __name__ == "__main__":
    main(args())
