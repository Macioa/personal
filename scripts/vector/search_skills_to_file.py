"""Run search_skills.py with the given args and write its stdout to --output-abs-path."""
import argparse
import subprocess
import sys
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("skills", nargs="+")
parser.add_argument("--output-abs-path", required=True)
args, passthrough = parser.parse_known_args()

script = Path(__file__).with_name("search_skills.py")
result = subprocess.run(
    [sys.executable, str(script), *args.skills, *passthrough],
    capture_output=True, text=True, encoding="utf-8",
)
if result.returncode != 0:
    sys.stderr.write(result.stderr)
    sys.exit(result.returncode)

out = Path(args.output_abs_path)
out.parent.mkdir(parents=True, exist_ok=True)
lines = result.stdout.splitlines()
if len(lines) != len(args.skills):
    sys.exit(f"expected {len(args.skills)} result lines, got {len(lines)}")
# One row per DB result: JD skills that normalize to the same result share a row ("JavaScript / TypeScript -> ...")
merged = {}
for s, l in zip(args.skills, lines):
    if s not in merged.setdefault(l, []):
        merged[l].append(s)
out.write_text("".join(f"{' / '.join(ss)} -> {l}\n" for l, ss in merged.items()), encoding="utf-8")
print(out)
