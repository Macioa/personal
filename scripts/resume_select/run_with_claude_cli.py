"""Structured-output request to the local Claude CLI, isolated to the prompt it is given."""
import json, shutil, subprocess, sys, tempfile

MODEL = "sonnet"
TIMEOUT = 600


# Returns a Gemini-shaped response so common.run handles both runners the same way.
def generate(text, schema):
    exe = shutil.which("claude") or sys.exit("claude CLI not found on PATH")
    cmd = [exe, "-p", "--model", MODEL, "--output-format", "json", "--json-schema", json.dumps(schema.model_json_schema()),
           "--tools", "", "--strict-mcp-config", "--setting-sources", "", "--disable-slash-commands", "--no-session-persistence",
           "--system-prompt", "Follow the task. Use only the input files in the message."]
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as cwd:  # no project CLAUDE.md or memory
        p = subprocess.run(cmd, input=text, capture_output=True, text=True, encoding="utf-8", timeout=TIMEOUT, cwd=cwd)
    if p.returncode:
        sys.exit(f"Claude request failed ({p.returncode}): {(p.stderr or p.stdout)[:500]}")
    r = json.loads(p.stdout)
    if r.get("is_error") or r.get("structured_output") is None:
        sys.exit(f"Claude returned no structured output: {p.stdout[:500]}")
    u = r.get("usage") or {}
    tokens = sum(u.get(k) or 0 for k in ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
    return {"usageMetadata": {"totalTokenCount": tokens},
            "candidates": [{"content": {"parts": [{"text": json.dumps(r["structured_output"])}]}}]}
