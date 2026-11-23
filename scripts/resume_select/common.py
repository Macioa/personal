"""Shared runner for the for-jd selection tasks: rulebook prompt -> Gemini REST -> pydantic -> checked output."""
import argparse, json, sys, time
from pathlib import Path
import requests
from pydantic import ValidationError

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "vector"))
from db import env  # noqa: E402

MODEL = "gemini-3.1-flash-lite"  # same as homepage-2026 netlify/functions/chat.mts
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
TASKS = ROOT / "tasks" / "resume" / "create" / "for-jd" / "tasks"
MAX_TRIES = 3


# Parse --company-role / --repo-path; return temp folder Path
def args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--company-role", required=True)
    ap.add_argument("--repo-path", default=str(ROOT))
    a = ap.parse_args()
    return a.repo_path, a.company_role, Path(a.repo_path) / "temp" / "applications" / a.company_role / "temp"


def read(folder, name):
    return (folder / name).read_text(encoding="utf-8")


def read_json(folder, name):
    t = read(folder, name)
    return json.loads(t[min(i for i in (t.find("["), t.find("{")) if i >= 0):])


# Rulebook text with placeholders filled, plus input files and the reply contract
def prompt(task_file, repo, role, inputs, contract):
    rules = (TASKS / task_file).read_text(encoding="utf-8").replace("<repo path>", repo).replace("[company-role]", role)
    files = "\n\n".join(f"=== {n} ===\n{c}" for n, c in inputs.items())
    return f"{rules}\n\nThe input files are below; do not read anything else.\n\n{files}\n\nReply contract: {contract}"


# One structured-output request; retries rate limits and server errors.
def generate(text, schema):
    body = {"contents": [{"role": "user", "parts": [{"text": text}]}],
            "generationConfig": {"temperature": 0, "responseMimeType": "application/json",
                                 "responseJsonSchema": schema.model_json_schema()}}
    for attempt in range(3):
        r = requests.post(URL, headers={"x-goog-api-key": env("RESUME_GEMINI_KEY")}, json=body, timeout=180)
        if r.status_code != 429 and r.status_code < 500:
            break
        if attempt < 2:
            time.sleep(2 ** (attempt + 1))
    if not r.ok:
        sys.exit(f"Gemini request failed ({r.status_code}): {r.text[:500]}")
    return r.json()


# Call Gemini with structured output; check() returns error str or None. Retries with the error fed back.
def run(text, schema, check):
    tokens, msg = 0, text
    for _ in range(MAX_TRIES):
        r = generate(msg, schema)
        tokens += r.get("usageMetadata", {}).get("totalTokenCount") or 0
        parts = (r.get("candidates") or [{}])[0].get("content", {}).get("parts") or []
        try:
            out = schema.model_validate_json("".join(p.get("text", "") for p in parts))
            err = check(out)
        except ValidationError as e:
            err = f"reply did not match the schema: {e}"
        if not err:
            return out, tokens
        msg = f"{text}\n\nYour previous reply was rejected: {err}\nFix it and reply again."
    sys.exit(f"Gemini reply failed validation after {MAX_TRIES} tries: {err}")


def write(folder, name, tokens, body):
    (folder / name).write_text(f"Tokens: {tokens}\n\n{body}\n", encoding="utf-8")
    print(folder / name)


def dump(x):
    return json.dumps(x, indent=2, ensure_ascii=False)
