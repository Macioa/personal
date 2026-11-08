"""Skill years with abstract groups, e.g. "AWS (11) + Other cloud services (11)".

Usage: python search_skills.py AWS "fast api" [--mode precise|start_to_end] [--json]
Needs env/local.env RESUME_READER_DB_URL. Terms are embedded locally with
gte-small (same model as edge function embed-skill) for fuzzy matching.
"""
import argparse, functools, json

import deps


# CLI args
def args():
    p = argparse.ArgumentParser()
    p.add_argument("skills", nargs="+")
    p.add_argument("--mode", choices=["start_to_end", "precise"], default="start_to_end")
    p.add_argument("--json", action="store_true", help="print full rows")
    return p.parse_args()


# Cached gte-small (Supabase ONNX build; mean pool + normalize, as in embed-skill)
@functools.cache
def model():
    from fastembed import TextEmbedding
    from fastembed.common.model_description import ModelSource, PoolingType
    name = "Supabase/gte-small"
    if name not in [m["model"] for m in TextEmbedding.list_supported_models()]:
        TextEmbedding.add_custom_model(model=name, pooling=PoolingType.MEAN, normalization=True,
                                       sources=ModelSource(hf=name), dim=384, model_file="onnx/model.onnx")
    return TextEmbedding(name)


# Run search_skills as resume_reader; print one label per term
def main(a):
    deps.ensure_deps()
    import psycopg, db, embed
    vecs = [embed.lit(v.tolist()) for v in model().embed(a.skills)]
    with psycopg.connect(db.env("RESUME_READER_DB_URL")) as conn:
        rows = conn.execute(
            "SELECT public.search_skills(%s, %s::extensions.vector(384)[], %s::public.skill_usage_mode)",
            (a.skills, vecs, a.mode)).fetchall()
    for (r,) in rows:
        print(json.dumps(r) if a.json else r["label"])


if __name__ == "__main__":
    main(args())
