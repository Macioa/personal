# Email Process

> AVOID HALLUCINATIONS, GUESSWORK, PARAPHRASING
> USE DIRECTLY QUOTED INFORMATION IN ALL TASKS
> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS
> Do not share private or inappropriate information.

1. Load personal info and scan the `info` folder.

2. Scan `temp/mail`. For each md, perform the requested task (send, fill missing text, add attachment, create folder, etc.).
   - If a send pertains to a job application: look up matching rows via `supabase/migrations/`, record the sent communication, and update related rows per the schema from the sent content only.
   - Success: remove the md and move the mail item out of the inbox into the appropriate folder.
   - Failure: add a failure report to the md (failure count + suspected reason).

3. Report success percentage, total success/fails, and list failed items (short answer).
