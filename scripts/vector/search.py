"""Hybrid (vector + keyword) search over call transcripts.

Usage: python search.py "<query>" [--limit 8] [--speaker Christy] [--backup <uuid> ...] [--context]
Needs env TRANSCRIBER_DB_URL (transcriber role).
"""
import argparse

import chunk, deps


# CLI args
def args():
    p = argparse.ArgumentParser()
    p.add_argument("query")
    p.add_argument("--limit", type=int, default=8)
    p.add_argument("--speaker")
    p.add_argument("--backup", action="append")
    p.add_argument("--context", action="store_true", help="also print turns around each hit")
    return p.parse_args()


# Run search_transcripts with a query embedding; print hits
def main(a):
    deps.ensure_deps()
    import db, embed
    vec = embed.lit(embed.query(a.query))
    with db.connect() as conn:
        rows = conn.execute(
            "SELECT * FROM public.search_transcripts(%s, %s::extensions.vector, %s, %s, %s::uuid[])",
            (a.query, vec, a.limit, a.speaker, a.backup)).fetchall()
        for tid, no, start, end, head, content, url, score in rows:
            # Cosine similarity of query vs chunk (score is rank-fusion only)
            sim = conn.execute(
                "SELECT 1 - (embedding OPERATOR(extensions.<=>) %s::extensions.vector)"
                " FROM public.transcript_chunks WHERE transcript_id = %s AND chunk_no = %s",
                (vec, tid, no)).fetchone()[0]
            print(f"== {head} [{chunk.ts(float(start))}-{chunk.ts(float(end))}] rank {score:.4f} sim {sim:.3f}")
            print(f"   transcript {tid} chunk {no} | {url}")
            print(content)
            if a.context:
                turns = conn.execute("SELECT public.get_transcript_window(%s, %s, %s)",
                                     (tid, start, end)).fetchone()[0]
                for t in turns:
                    print(f"   [{chunk.ts(float(t['start_s']))}] {t['speaker']}: {t['text']}")
            print()
        if not rows:
            print("no hits")


if __name__ == "__main__":
    main(args())
