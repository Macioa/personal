# Resume for JD (master)

Run as `jd-master` agent.

Input: JD md. Set `[company-role]` and `<repo path>` (absolute path of project root).

Create folder `<repo path>/temp/applications/[company-role]/temp` before starting groups.

Run groups synchronously, in order. Run steps inside each group asynchronously (all at once); wait for all before next group.
Task file paths below are relative to this file's folder (`<repo path>/tasks/resume/create/for-jd/`).
Steps marked (direct): run yourself, no agent, no token line. Other steps in isolated context (fresh `jd-step` agent). Pass only: task file path, `[company-role]`, `<repo path>`. Do not read files unless instructed.
After each step completes, prepend its token usage (from the Agent result's usage, not the agent's own report) to its output file as first line: `Tokens: <n>`, followed by a blank line.

**Group 1**
- (direct) `tasks/jd-to-md.md` → `original_jd.md`
- (direct) `tasks/jd-resume-view.md` → `resume-view-*.md`

**Group 2**
- `tasks/jd-requirements.md` → `jd_requirements.md`

**Group 3**
- (opus, low effort) `tasks/jd-aliases.md` → `aliases.md`

**Group 4**
- (direct) `tasks/jd-skill-search.md` → `skill_search_output.md`

**Group 5**
- `tasks/jd-embedding-review.md` → `embedding_suggestions.md`

!!! STOP Here and present top jd requirements vs fuzzy matches. Continue after user approval

**Group 6**
- `tasks/jd-select-skills.md` → `selected_skills.md`
- `tasks/jd-select-employment.md` → `selected_employment.md`
- `tasks/jd-select-projects.md` → `selected_projects.md`
- `tasks/jd-select-pitches.md` → `selected_pitches.md`
