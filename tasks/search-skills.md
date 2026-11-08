# Search skills

> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

Skill years plus abstract group years, for resume skill rows like `AWS (2) + Other cloud services (4)`. Schema: `supabase/migrations/4_resume.sql` (`skill_groups`, `skill_group_members`, `search_skills`).

1. Shell: `python scripts/vector/search_skills.py <skill> [<skill> ...] [--mode precise|start_to_end] [--json]`. Fuzzy: terms embedded locally (gte-small, same as stored).
2. SQL (Supabase MCP): `select search_skills(array['<skill>', ...][, null, '<mode>'])`.
3. Fuzzy (unknown names matched by embedding; chat): edge function `embed-skill`, POST `{"query": ["<skill>", ...], "mode": "<mode>"}` with the caller's `Authorization` JWT (from `get-jwt`).
4. Group years exclude the searched skill. Unknown terms with no embedding return the term alone.
5. New skills/groups are embedded automatically by trigger. Add group membership in `skill_group_members`.
