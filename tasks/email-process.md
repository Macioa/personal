# Email Process

> AVOID HALLUCINATIONS, GUESSWORK, PARAPHRASING
> USE DIRECTLY QUOTED INFORMATION IN ALL TASKS
> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS
> Do not share private or inappropriate information.

1. Load personal info and scan the `info` folder.
   - Before sending a reply that touches school, degree, or graduation, quote the `Education` row in `personal_info_and_docs`.

2. Scan `temp/mail`. For each md, perform the requested task (send, fill missing text, add attachment, create folder, etc.).
   - Fill schedule / availability / start-date from Google Calendar per `atomic.md` (busy/free, upcoming). Do not fail those fields for absence from personal info alone.
   - On send: use mailbox from `applications.which_personal_email_used` (`outlook` → Outlook; `gmail` → Gmail). If unset, ask before sending.
   - On send (Gmail): use Gmail default send-as signature via Composio; append if the API omits it. Do not invent a signature.
   - Job-application send: look up matching rows via `supabase/migrations/`. If none exists, create the `applications` row from email/thread facts only, then always record the sent communication in `application_conversations` (and related interview/rows when present). Never skip Supabase logging because a row was missing.
   - Success: remove the md and move the mail item out of the inbox into the appropriate folder.
   - Failure: add a failure report to the md (failure count + suspected reason).

3. Clear the inbox by moving remaing messages into appropriate folders. If they pertain to a job application, make sure they are recorded in supabase. If they appear imporant leave them in the inbox for manual review.

4. Report success percentage, total success/fails, and list failed items (short answer).
