# JD Select Employment

1. Review `<repo path>/temp/applications/[company-role]/temp/jd_requirements.md`, `skill_search_output.md` and `resume-view-employment.md`, same folder.
2. For each employment: select top 3 bullets and top 5 skills that best align and cover broadest territory for skill match. Prioritize explicit named matches first, then congruent skills.
   - A skill in the same "Other" group as an explicit JD skill in `skill_search_output.md` counts as an explicit match. Order: explicit JD skills, then their stand-ins, then congruent skills.
   - Also treat as explicit any employment skill whose name matches a JD skill or alias in `jd_requirements.md`, even if absent from `skill_search_output.md`.
   - Across all employments, every JD skill present in any employment's own `skills` must appear at least once. Do not repeat a skill on every job if it crowds out an unshown JD skill.
   - Bullets: prefer bullets naming JD tools (Docker, AWS, AI/LLM tools) over generic ones.
   - Select only from that employment's own `bullets` and `skills`. Do not add, rename or reword.
3. Output to `selected_employment.md`, same folder, JSON format. Keep every employment and all its resume view data verbatim; only `bullets` (3) and `skills` (5) are reduced.
