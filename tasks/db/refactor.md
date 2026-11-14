# DB refactor

> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

Reorganize `supabase/migrations/*.sql` (move tables, functions, indexes between files; split or rename files) without changing the schema. One-shot files: no ALTER unless no CREATE form exists (RLS enable/force, default privileges, database settings, account-specific placeholders).

1. Plan the moves. Order files so every dependency comes first: FK targets before referencing tables; tables, functions and views before SQL functions and views that read them (Postgres checks `LANGUAGE sql` bodies at create time); roles before policies that name them.
2. Whole-file renames and moves: always `git mv`, never plain `mv`.
3. Splitting a block out into a new file, keeping history (`git log --follow new.sql` reaches the source). Commits need the user's OK. Per new file:
   ```bash
   git switch -c split-<new>
   git mv <src>.sql <new>.sql && git commit -m "split <src> -> <new>"
   git switch -
   git mv <src>.sql <tmp>.sql && git commit -m "split <src> -> <tmp>"
   git merge --no-ff split-<new>        # conflict: both renamed <src>
   git rm --cached <src>.sql 2>/dev/null; git add <new>.sql <tmp>.sql
   git commit -m "merge split <new>"
   git mv <tmp>.sql <src>.sql && git commit -m "restore <src>"
   git branch -d split-<new>
   ```
   Then trim: delete everything but the block from `<new>.sql`, and the block from `<src>.sql`. Repeat for each new file, one at a time.
   Without commits (blocks moved by edit only): history is still findable with `git blame -C -C <new>.sql` and `git diff --cached --color-moved=zebra`.
4. Fold extraneous ALTERs into their CREATE statements (column types, FK `ON DELETE`, defaults, `CREATE POLICY ... TO` roles).
5. Update references to renamed files in `tasks/`, `skills/` and SQL comments (`grep -rn "<old file name>"`).
6. Verify against the prior commit: copy `git show HEAD:supabase/migrations/<f>` for each file into `<scratch>/head/`, then compare normalized statement sets (comments stripped, whitespace collapsed, `$$` bodies kept whole, order ignored) of `<scratch>/head` vs `supabase/migrations`. The only differences allowed are the folds from step 4. Report any others.
7. Verify against live (Supabase MCP `execute_sql`, read-only): for every folded or moved object, check the live state matches the files (column types, `pg_constraint.confdeltype`, `pg_policies.roles`, grants, comments). Report live objects that no file defines.
8. Show `git status` (renames must show as `R`). Commit only when the user asks.
