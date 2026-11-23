"""Shared runner for the for-jd selection tasks: rulebook prompt -> selected runner -> pydantic -> checked output."""
import argparse, importlib, json, sys
from pathlib import Path
from pydantic import ValidationError

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "vector"))

TASKS = ROOT / "tasks" / "resume" / "create" / "for-jd" / "tasks"
MAX_TRIES = 3
RUNNERS = {"gemini": "run_with_gemini_remote", "claude": "run_with_claude_cli"}
_runner = "gemini"


# Parse --company-role / --repo-path / --runner; return temp folder Path
def args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--company-role", required=True)
    ap.add_argument("--repo-path", default=str(ROOT))
    ap.add_argument("--runner", choices=RUNNERS, default="gemini")
    a = ap.parse_args()
    global _runner
    _runner = a.runner
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


# Call the selected runner with structured output; check() returns error str or None. Retries with the error fed back.
def run(text, schema, check):
    generate = importlib.import_module(RUNNERS[_runner]).generate
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
    sys.exit(f"{_runner} reply failed validation after {MAX_TRIES} tries: {err}")


def write(folder, name, tokens, body):
    (folder / name).write_text(f"Tokens: {tokens}\n\n{body}\n", encoding="utf-8")
    print(folder / name)


def dump(x):
    return json.dumps(x, indent=2, ensure_ascii=False)
