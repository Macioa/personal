# Email Prep

> AVOID HALLUCINATIONS, GUESSWORK, PARAPHRASING
> USE DIRECTLY QUOTED INFORMATION IN ALL TASKS
> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS
> Do not share private or inappropriate information.

> ALWAYS USE DIRECT, CONCISE, AND FORMAL LANGUAGE.

1. Load personal info and scan the `info` folder.

2. Check unread mail and folder structure. For each message:
   - If it pertains to a job application:
     - Look up matching rows in Supabase using `supabase/migrations/` (`applications` and related tables).
     - Use that history as context.
     - Record the communication and update related rows per the schema from the email content only.
   - If it requires action (reply, process, invite, etc.): create a unique md in `temp/mail`.
     - Direct and short.
     - Summary + proposed action (draft reply — missing personal info → `[INSERT X INFO HERE]`).
     - End every draft reply with this very small fine print: `This email was drafted by custom built AI agents and manually reviewed by the sender before sending.`
   - If it does not: move it out of the inbox into the appropriate folder.
     - No folder → md in `temp/mail` to create one and why.

3. Create an md in `temp/calendar` listing today's events.
   - Links and minimum necessary video-call connection info only.
