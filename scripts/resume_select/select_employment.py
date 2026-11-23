"""jd-select-employment.md via --runner -> selected_employment.md
Usage: python scripts/resume_select/select_employment.py --company-role <company-role> [--runner gemini|claude] [--repo-path <abs>]"""
import json, re
from pydantic import BaseModel
from common import args, read, read_json, prompt, run, write, dump
from db import env, pg_connect


# Months value of an entry's end date, for placing growth rows. Present sorts first, undated last.
def end_months(entry):
    dates = entry.get("dates") or ""
    if "present" in dates.lower():
        return float("inf")
    found = re.findall(r"(?:(\d{1,2})/)?(\d{4})", dates)
    return int(found[-1][1]) * 12 + int(found[-1][0] or 12) if found else -1


# Insert growth rows by end date; employer order is left as the view returned it.
def with_growth(jobs, growth):
    for g in growth or []:
        at = next((i for i, j in enumerate(jobs) if end_months(j) < end_months(g)), len(jobs))
        jobs.insert(at, g)
    return jobs


repo, role, d = args()
growth_file = d / "resume-view-growth_history.md"
jobs = with_growth(read_json(d, "resume-view-employment.md"),
                   json.loads(growth_file.read_text(encoding="utf-8")) if growth_file.exists() else None)

# Whole alternate_skills table (resume_reader): JD skill I lack -> direct competitors I have
with pg_connect(env("RESUME_READER_DB_URL")) as db:
    alternates = {n: alts for n, alts in db.execute(
        "SELECT a.skill_name, array(SELECT s.name FROM unnest(a.alternate_skill_ids) WITH ORDINALITY u(id, o) "
        "JOIN public.skills s ON s.id = u.id ORDER BY u.o) FROM public.alternate_skills a ORDER BY a.skill_name").fetchall()}


class Pick(BaseModel):
    index: int  # position in resume-view-employment.md (0-based)
    bullets: list[str]
    skills: list[str]


class Reply(BaseModel):
    employment: list[Pick]


# "AWS(similar to Azure)" -> "AWS" if Azure lists AWS as an alternate; else unchanged (fails the verbatim check)
def base(x):
    m = re.fullmatch(r"(.+?)\(similar to (.+)\)", x)
    return m[1] if m and m[1] in alternates.get(m[2], []) else x


def check(r):
    if sorted(p.index for p in r.employment) != list(range(len(jobs))):
        return f"need exactly one entry per employment, indexes 0..{len(jobs) - 1}"
    for p in r.employment:
        j = jobs[p.index]
        for k, n in (("bullets", 3), ("skills", 5)):
            src, got = j.get(k) or [], getattr(p, k)
            if not src:  # nothing to pick from: drop whatever the model returned
                setattr(p, k, [])
                continue
            if len(got) != min(n, len(src)) or len(set(got)) != len(got):
                return f"{j['name']} (index {p.index}): need {min(n, len(src))} distinct {k}, got {len(got)}"
            # bad = [x for x in got if base(x) not in src]
            # if bad:
            #     return f"{j['name']} (index {p.index}): {k} not verbatim from its own list: {bad}"


text = prompt("jd-select-employment.md", repo, role,
              {"jd_requirements.md": read(d, "jd_requirements.md"),
               "skill_search_output.md": read(d, "skill_search_output.md"),
               "resume-view-employment.md": dump(jobs),
               "alternate_skills.md": dump(alternates)},
              "return `employment`: one entry per employment, `index` = its 0-based position in resume-view-employment.md, "
              "`bullets` = its top 3 bullets (fewer if it has fewer; [] if it has none) and `skills` = its top 5 skills (fewer if it has fewer), each copied verbatim from that employment's own lists, in priority order. "
              "A skill used as a stand-in for an `alternate_skills.md` JD skill is written as `<skill>(similar to <JD skill>)`, "
              "e.g. `AWS(similar to Azure)`; every other skill is verbatim. All other fields are kept verbatim automatically.")
r, tokens = run(text, Reply, check)
picks = {p.index: p for p in r.employment}
out = [{**j, "bullets": picks[i].bullets, "skills": picks[i].skills} if "bullets" in j
       else {**j, "skills": picks[i].skills} for i, j in enumerate(jobs)]
write(d, "selected_employment.md", tokens, dump(out))
