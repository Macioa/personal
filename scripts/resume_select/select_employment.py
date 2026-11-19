"""jd-select-employment.md via Gemini -> selected_employment.md
Usage: python scripts/resume_select/select_employment.py --company-role <company-role> [--repo-path <abs>]"""
from pydantic import BaseModel
from common import args, read, read_json, prompt, run, write, dump

repo, role, d = args()
jobs = read_json(d, "resume-view-employment.md")


class Pick(BaseModel):
    index: int  # position in resume-view-employment.md (0-based)
    bullets: list[str]
    skills: list[str]


class Reply(BaseModel):
    employment: list[Pick]


def check(r):
    if sorted(p.index for p in r.employment) != list(range(len(jobs))):
        return f"need exactly one entry per employment, indexes 0..{len(jobs) - 1}"
    for p in r.employment:
        j = jobs[p.index]
        for k, n in (("bullets", 3), ("skills", 5)):
            src, got = j.get(k) or [], getattr(p, k)
            if len(got) != min(n, len(src)) or len(set(got)) != len(got):
                return f"{j['name']} (index {p.index}): need {min(n, len(src))} distinct {k}, got {len(got)}"
            bad = [x for x in got if x not in src]
            if bad:
                return f"{j['name']} (index {p.index}): {k} not verbatim from its own list: {bad}"


text = prompt("jd-select-employment.md", repo, role,
              {"jd_requirements.md": read(d, "jd_requirements.md"),
               "skill_search_output.md": read(d, "skill_search_output.md"),
               "resume-view-employment.md": dump(jobs)},
              "return `employment`: one entry per employment, `index` = its 0-based position in resume-view-employment.md, "
              "`bullets` = its top 3 bullets and `skills` = its top 5 skills, each copied verbatim from that employment's own lists, in priority order. "
              "All other fields are kept verbatim automatically.")
r, tokens = run(text, Reply, check)
picks = {p.index: p for p in r.employment}
out = [{**j, "bullets": picks[i].bullets, "skills": picks[i].skills} if "bullets" in j
       else {**j, "skills": picks[i].skills} for i, j in enumerate(jobs)]
write(d, "selected_employment.md", tokens, dump(out))
