# JD Skill Search

Do not read the script. Arg is absolute path:
- `<abs output>`: `<repo path>/temp/applications/[company-role]/temp/skill_search_output.md`

1. Scan `<repo path>/temp/applications/[company-role]/temp/aliases.md`. Take all skills from `Skill` column, plus, for each abstract skill, the first 2 tools in its `Associated skills` column.
2. Run fuzzy search on all, one call:
   `python scripts/vector/search_skills_to_file.py "<skill>" "<skill>" ... --output-abs-path "<abs output>"` ([search_skills_to_file.py](../../../../../scripts/vector/search_skills_to_file.py))
