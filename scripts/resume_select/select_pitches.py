"""jd-select-pitches.md via --runner -> selected_pitches.md
Usage: python scripts/resume_select/select_pitches.py --company-role <company-role> [--runner gemini|claude] [--repo-path <abs>]"""
from pydantic import BaseModel
from common import args, read, read_json, prompt, run, write, dump

repo, role, d = args()
pitches = read_json(d, "resume-view-pitches.md")
lo, hi = min(1, len(pitches)), min(3, len(pitches))


class Reply(BaseModel):
    indexes: list[int]  # positions in resume-view-pitches.md (0-based), best first


def check(r):
    i = r.indexes
    if not lo <= len(i) <= hi or len(set(i)) != len(i) or not all(0 <= x < len(pitches) for x in i):
        return f"need {lo}-{hi} distinct valid indexes 0..{len(pitches) - 1}, got {i}"


text = prompt("jd-select-pitches.md", repo, role,
              {"original_jd.md": read(d, "original_jd.md"), "resume-view-pitches.md": dump(pitches)},
              f"return `indexes`: 2-{hi} 0-based positions in resume-view-pitches.md, best first; at least 1. If none fit the JD, pick the pitch(es) whose `use_when` says to use them when no other pitch fits. Pitches are copied verbatim automatically.")
if pitches:
    r, tokens = run(text, Reply, check)
    write(d, "selected_pitches.md", tokens, dump([pitches[i] for i in r.indexes]))
else:
    write(d, "selected_pitches.md", 0, "[]")
