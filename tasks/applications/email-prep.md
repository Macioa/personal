# Email Prep

> AVOID HALLUCINATIONS, GUESSWORK, PARAPHRASING
> USE DIRECTLY QUOTED INFORMATION IN ALL TASKS
> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS
> Do not share private or inappropriate information.

> ALWAYS USE DIRECT, CONCISE, AND FORMAL LANGUAGE.

1. Load personal info and scan the `info` folder.
   - When a draft touches school, degree, or graduation, quote the `Education` row in `personal_info_and_docs`.

2. Check unread mail and folder structure. For each message:
   - Check to see if it has already been replied or acted by reviewing sent and recently received emails for matches. If it has been acted upon without logging, log it.
   - Job application: look up matching rows via `supabase/migrations/` (`applications` and related tables); use that history as context; record the communication and update related rows per the schema from the email content only.
   - Needs action (reply, process, invite, etc.): create a unique md in `temp/mail`.
     - Direct and short.
     - Summary + proposed action (draft reply — missing personal info → `[INSERT X INFO HERE]`).
     - No signature in drafts (no sign-off, no fine print); email-process applies it on send.
   - No action needed: move out of inbox into the appropriate folder.
     - No folder → md in `temp/mail` to create one and why.

3. Create an md in `temp/calendar` listing today's events.
   - Links and minimum necessary video-call connection info only.
