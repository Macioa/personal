# personal

Private stash for reusable personal info and LLM tasks — handling emails, applying to jobs, refactoring code and documents, recording demo videos, and daily summaries.

## Install

Run `skills/setup.md` with Claude, Cursor, or a coding agent.

## Layout

- `info/` — facts, preferences, context worth reusing across chats
- `skills/` — reusable capabilities (setup, refactor, recording, PR triage)
- `tasks/` — personal runbooks (email, jobs, daily summaries)
- `scripts/` — local scripts (call transcription)
- `docs/` — operational notes (atomic routing, installs, logins)
- `supabase/` — schema and migrations for personal data

## Tools

Human only (Claude/Cursor cannot access these directly):

- SMS Backup & Restore (SyncTech) — text backup and storage
- ACR — phone call recordings

LLM-accessible:

- Browsing — Claude in Chrome, EasyPlaywrightMCP, Browser MCP (in that order)
- Email/Calendar — Composio (Gmail, Google Calendar)
- Fathom — call transcripts (preferred)
