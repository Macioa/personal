"""Write each public.resume key to <out dir>/resume-view-<key>.md as JSON (resume_reader role).
Usage: python scripts/resume_view.py --output-abs-path <abs dir>"""
import argparse, json, os, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent / "vector"))
from db import env, pg_connect

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument("--output-abs-path", required=True, help="absolute output directory")
a = ap.parse_args()
if not os.path.isabs(a.output_abs_path):
    ap.error("--output-abs-path must be absolute")
out = Path(a.output_abs_path)
out.mkdir(parents=True, exist_ok=True)
with pg_connect(env("RESUME_READER_DB_URL")) as c:
    cur = c.execute("select * from public.resume")
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    cur = c.execute('select "desc", photo_url, desc_url from public.profile_photo order by priority desc nulls last')
    photo_cols = [d[0] for d in cur.description]
    photos = [dict(zip(photo_cols, r)) for r in cur.fetchall()]
data = dict(zip(cols, rows[0])) if len(rows) == 1 else [dict(zip(cols, r)) for r in rows]
if len(cols) == 1 and isinstance(data, dict):
    data = data[cols[0]]
if isinstance(data, str):
    data = json.loads(data)
data["profile_photo"] = photos
for k, v in data.items():
    (out / f"resume-view-{k}.md").write_text(json.dumps(v, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"resume-view-{k}.md")
