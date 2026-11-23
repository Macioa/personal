"""jd-select-skills.md via --runner -> selected_skills.md
Usage: python scripts/resume_select/select_skills.py --company-role <company-role> [--runner gemini|claude] [--repo-path <abs>]"""
from pydantic import BaseModel, Field
from common import args, read, prompt, run, write

repo, role, d = args()
rows = [l for l in read(d, "skill_search_output.md").splitlines() if l.strip()]


class Reply(BaseModel):
    rows: list[str] = Field(description="selected rows copied exactly from skill_search_output.md")


def check(r):
    if not 10 <= len(r.rows) <= 15:
        return f"need 10-15 rows, got {len(r.rows)}"
    bad = [x for x in r.rows if x not in rows]
    if bad:
        return f"rows not copied exactly from skill_search_output.md: {bad}"
    if len(set(r.rows)) != len(r.rows):
        return "duplicate rows"


text = prompt("jd-select-skills.md", repo, role,
              {"skill_search_output.md": "\n".join(rows), "jd_requirements.md": read(d, "jd_requirements.md")},
              "return `rows`: 10-15 rows, each copied character-for-character from skill_search_output.md.")
r, tokens = run(text, Reply, check)
write(d, "selected_skills.md", tokens, "\n".join(r.rows))
