# JD Select Employment

1. Review `<repo path>/temp/applications/[company-role]/temp/jd_requirements.md`, `skill_search_output.md` and `resume-view-employment.md`, same folder, plus `alternate_skills.md` (JD skill I lack -> direct competitors I have).
2. For each employment: select top 3 bullets and top 5 skills that best align and cover broadest territory for skill match. Prioritize explicit named matches first, then congruent skills.
   - A skill in the same "Other" group as an explicit JD skill in `skill_search_output.md` counts as an explicit match. Order: explicit JD skills, then their stand-ins, then congruent skills.
   - If a JD skill is a key in `alternate_skills.md`, its listed alternates in an employment's `skills` count as explicit matches: rank right after explicit JD skills, before same-group stand-ins. Write each as `<skill>(similar to <JD skill>)`, e.g. `AWS(similar to Azure)`.
   - Also treat as explicit any employment skill whose name matches a JD skill or alias in `jd_requirements.md`, even if absent from `skill_search_output.md`.
   - Across all employments, every JD skill present in any employment's own `skills` must appear at least once. Do not repeat a skill on every job if it crowds out an unshown JD skill.
   - Bullets: prefer bullets naming JD tools (Docker, AWS, AI/LLM tools) over generic ones. Each `bullets` list is in priority order, highest first: break ties by keeping the earlier bullet.
   - Select only from that employment's own `bullets` and `skills`. Do not add, rename or reword, except the `(similar to <JD skill>)` suffix above.
3. Output to `selected_employment.md`, same folder, JSON format. Keep every employment and all its resume view data verbatim; only `bullets` (3) and `skills` (5) are reduced.
