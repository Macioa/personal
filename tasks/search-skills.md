# Search skills

> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

Skill years plus abstract group years, for resume skill rows like `AWS (2) + Other cloud services (4)`. Schema: `supabase/migrations/4_resume.sql` (`skill_groups`, `skill_group_members`, `search_skills`).

Durations: the named skill uses `precise` (time actually used), the "Other" groups `start_to_end` (first to last use). Override either.

1. Shell: `python scripts/vector/search_skills.py <skill> [<skill> ...] [--skill-mode <mode>] [--group-mode <mode>] [--json]`. Fuzzy: terms embedded locally (gte-small, same as stored).
2. SQL (Supabase MCP): `select search_skills(array['<skill>', ...][, null, '<skill_mode>', '<group_mode>'])`.
3. Fuzzy (unknown names matched by embedding; chat): edge function `embed-skill`, POST `{"query": ["<skill>", ...], "skillMode": "<mode>", "groupMode": "<mode>"}` with the caller's `Authorization` JWT (from `get-jwt`).
4. Group years exclude the searched skill. Unknown terms show as `<term> (0)`, plus the nearest groups when embedded and similar enough (`p_group_min_sim`, default 0.815), e.g. `Azure (0) + Other cloud services (...)`. Nonsense terms get no groups. Group matching uses each group's `desc`: keep it a one-line list of the category's common tools.
5. New skills/groups are embedded automatically by trigger. Add group membership in `skill_group_members`.
