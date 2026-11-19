"""Shared runner for the for-jd selection tasks: rulebook prompt -> Gemini (LangChain) -> pydantic -> checked output."""
import argparse, json, os, sys
from pathlib import Path
from langchain_google_genai import ChatGoogleGenerativeAI

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "vector"))
from db import env  # noqa: E402

MODEL = "gemini-3.1-flash-lite"  # same as homepage-2026 netlify/functions/chat.mts
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


# Call Gemini with structured output; check() returns error str or None. Retries with the error fed back.
def run(text, schema, check):
    llm = ChatGoogleGenerativeAI(model=MODEL, api_key=env("RESUME_GEMINI_KEY"), temperature=0, max_retries=2)
    s = llm.with_structured_output(schema, include_raw=True)
    tokens, msg = 0, text
    for _ in range(MAX_TRIES):
        r = s.invoke(msg)
        tokens += ((r["raw"].usage_metadata or {}).get("total_tokens") or 0)
        out = r["parsed"]
        err = r.get("parsing_error") or (check(out) if out is not None else "no parsed reply")
        if not err:
            return out, tokens
        msg = f"{text}\n\nYour previous reply was rejected: {err}\nFix it and reply again."
    sys.exit(f"Gemini reply failed validation after {MAX_TRIES} tries: {err}")


def write(folder, name, tokens, body):
    (folder / name).write_text(f"Tokens: {tokens}\n\n{body}\n", encoding="utf-8")
    print(folder / name)


def dump(x):
    return json.dumps(x, indent=2, ensure_ascii=False)
