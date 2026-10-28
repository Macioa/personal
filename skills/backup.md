# Backup

> NO GUESS/PARAPHRASE. DELETE ONLY WHAT USER SAYS; NO ARCHIVE TABLES/SOFT DELETE.
> NO DELETE BEFORE USER YES + BACKUP WRITTEN.

Delete user-specified Supabase rows (MCP; schema `supabase/migrations/`), JSONL backup first.

1. **Scope.** Spec → `WHERE` per table; unclear → ask. Spec date → also `todolist` `completed` with `target_date` before it. FK children/link tables (migrations or `information_schema`): include only on yes.
2. **Preview.** `SELECT *` matches. Per table: count + rows (key cols; full on request) + exact `DELETE`. Stop for yes; scope change → 1.
3. **Back up.** `backups/db-<YYYY-MM-DD>-<slug>[-2…].jsonl`, one line per row as selected:
   `{"table":"<schema.table>","deleted_at":"<ISO-8601>","row":{...}}`
   Re-read; lines ≠ preview total → stop.
4. **Delete.** One transaction, children → parents, `RETURNING` PK. Keys ≠ backup → `ROLLBACK`, report.
5. **Blocked** (permission, RLS, FK, MCP read-only/down, tool declined): no workaround. Give full SQL (`sql` block, transaction, dependency order) + backup path + cause.
6. **Summary.** Per table: rows removed + identifying values; backup as markdown link (`[db-….jsonl](backups/db-….jsonl)`); anything not removed + why.

## Restore

Per line, parents → children: `INSERT INTO <table> SELECT * FROM jsonb_populate_record(NULL::<table>, '<row>'::jsonb);`
