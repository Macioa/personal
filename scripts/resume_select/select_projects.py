"""jd-select-projects.md via --runner -> selected_projects.md
Usage: python scripts/resume_select/select_projects.py --company-role <company-role> [--runner gemini|claude] [--repo-path <abs>]"""
from pydantic import BaseModel
from common import args, read, read_json, prompt, run, write, dump

repo, role, d = args()
projects = read_json(d, "resume-view-projects.md")


class Pick(BaseModel):
    index: int  # position in resume-view-projects.md (0-based)
    skills: list[str]


class Reply(BaseModel):
    projects: list[Pick]


def check(r):
    idx = [p.index for p in r.projects]
    if len(idx) != min(3, len(projects)) or len(set(idx)) != len(idx) or not all(0 <= i < len(projects) for i in idx):
        return f"need {min(3, len(projects))} distinct valid indexes 0..{len(projects) - 1}, got {idx}"
    for p in r.projects:
        pr = projects[p.index]
        src = pr.get("skills") or []
        if len(p.skills) != min(5, len(src)) or len(set(p.skills)) != len(p.skills):
            return f"{pr['name']} (index {p.index}): need {min(5, len(src))} distinct skills, got {len(p.skills)}"
        bad = [x for x in p.skills if x not in src]
        if bad:
            return f"{pr['name']} (index {p.index}): skills not verbatim from its own list: {bad}"


text = prompt("jd-select-projects.md", repo, role,
              {"jd_requirements.md": read(d, "jd_requirements.md"),
               "skill_search_output.md": read(d, "skill_search_output.md"),
               "resume-view-projects.md": dump(projects)},
              "return `projects`: the 3 selected, best first; `index` = 0-based position in resume-view-projects.md, "
              "`skills` = 5 skills copied verbatim from that project's own `skills`, in priority order. All other fields are kept verbatim automatically.")
r, tokens = run(text, Reply, check)
write(d, "selected_projects.md", tokens, dump([{**projects[p.index], "skills": p.skills} for p in r.projects]))
