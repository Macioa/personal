# JD Embedding Review

1. Compare `<repo path>/temp/applications/[company-role]/temp/skill_search_output.md` vs `aliases.md`, same folder.
2. Make `embedding_suggestions.md`, same folder. Table list of suggestions to improve fuzzy matches:
   - DB embeddings
   - Skill descriptions (`skills.desc`)
   - Groupings (`skill_groups`, `skill_group_members`)
   - Avoid suggestions that might break existing associations
   - Avoid unecessary changes. Do not make suggestions without impact. No or few suggestions is an acceptable output.

   Each item: what to change, boolean userapproved (false for all), exact new value, why (which JD skill missed or mismatched).

