"""Skill years with abstract groups, e.g.
"AWS (4) + Other cloud services (Google Cloud, Cloud Functions, total 10)". Unknown skill: "Azure (0) + ...".
Skill years default to precise, group years to start_to_end.

Usage: python search_skills.py AWS "fast api" [--skill-mode precise|start_to_end]
       [--group-mode precise|start_to_end] [--json]
Needs env/local.env RESUME_READER_DB_URL. Terms are embedded locally with
gte-small (same model as edge function embed-skill) for fuzzy matching.
"""
import argparse, functools, json

import deps

GTE_SMALL = "Supabase/gte-small"
MODES = ["precise", "start_to_end"]
SEARCH_SQL = ("SELECT public.search_skills(%s, %s::extensions.vector(384)[],"
              " %s::public.skill_usage_mode, %s::public.skill_usage_mode)")


# CLI options
def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("skills", nargs="+")
    p.add_argument("--skill-mode", choices=MODES, default="precise", help="years for the named skill")
    p.add_argument("--group-mode", choices=MODES, default="start_to_end", help="years for Other groups")
    p.add_argument("--json", action="store_true", help="print full rows")
    return p.parse_args()


# Cached gte-small (Supabase ONNX build; mean pool + normalize, as in embed-skill)
@functools.cache
def gte_small():
    from fastembed import TextEmbedding
    from fastembed.common.model_description import ModelSource, PoolingType
    if GTE_SMALL not in [m["model"] for m in TextEmbedding.list_supported_models()]:
        TextEmbedding.add_custom_model(model=GTE_SMALL, pooling=PoolingType.MEAN, normalization=True,
                                       sources=ModelSource(hf=GTE_SMALL), dim=384, model_file="onnx/model.onnx")
    return TextEmbedding(GTE_SMALL)


# pgvector literals for each term
def embed_terms(terms):
    import embed
    return [embed.lit(v.tolist()) for v in gte_small().embed(terms)]


# search_skills rows as resume_reader
def search(terms, term_vectors, skill_mode, group_mode):
    import psycopg, db
    with psycopg.connect(db.env("RESUME_READER_DB_URL")) as conn:
        params = (terms, term_vectors, skill_mode, group_mode)
        return [row for (row,) in conn.execute(SEARCH_SQL, params).fetchall()]


# One label (or full JSON row) per term
def print_rows(rows, as_json):
    for row in rows:
        print(json.dumps(row) if as_json else row["label"])


def main(opts):
    deps.ensure_deps()
    rows = search(opts.skills, embed_terms(opts.skills), opts.skill_mode, opts.group_mode)
    print_rows(rows, opts.json)


if __name__ == "__main__":
    main(parse_args())
