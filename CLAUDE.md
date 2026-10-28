# personal

Private stash for personal info and LLM tasks. Layout and install: see `README.md`.

Rules live in `.cursor/rules/` (shared with Cursor). All are always-apply:

@.cursor/rules/atomic.mdc
@.cursor/rules/never-delete-emails.mdc
@.cursor/rules/education-incomplete.mdc
@.cursor/rules/application-langs-certs-sites.mdc

## Claude Code notes

- Runbooks in `skills/` and `tasks/` are exposed as Claude skills under `.claude/skills/`. Edit the source md, not the wrapper.
- MCP servers (`.mcp.json`): `EasyPlaywrightMCP`, `composio` (Gmail, Google Calendar), `supabase`. Use these over other connectors, per `atomic.mdc`. Browsing order: Claude in Chrome, EasyPlaywrightMCP, Browser MCP.
- Schedule/todos: skill `get_schedule` (DB only).
- `local.env` holds machine paths; never commit it.
