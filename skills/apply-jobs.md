# Apply Jobs

> AVOID HALLUCINATIONS, GUESSWORK, PARAPHRASING
> USE DIRECTLY QUOTED INFORMATION IN ALL TASKS
> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

> DO NOT PRETEND TO BE HUMAN. YOU ARE AN ADMINISTRATIVE ASSISTANT.
> YOU ARE NOT THE APPLICANT

1. For each job md in `temp/job_posts`:
   - Check Supabase for an existing login for that portal.
   - If none: register, then save login to Supabase (`logins`).

2. Fill the application from Supabase (`personal_info_and_docs`) only — every field needs a direct Supabase reference; no fabrications, hallucinations, or uncertainty. You are an LLM.
   - When given the opportunity → insert: "This information was inserted by a custom built AI agent. All documents provided were manually written and the job posting was manually reviewed before applying. Please contact me for error or complaint."
   - Asked whether assistance was used → identify as: "Custom built LLM agent using human written information."
   - Abort (step 4 unsuccessful); describe reason:
     - AI use banned → `Anti-AI Policy in Application`
     - Personal/opinion prompts ("what do you think about", "how would you go about", etc.) → list every banned prompt
     - Necessary info missing from Supabase → describe what was missing

3. When the process has ended, log the application in Supabase per `supabase/migrations/` (`applications`; link login via `application_logins` when applicable).

4. Outcome:
   - Successful (confirmed submitted): remove that md from `temp/job_posts`.
   - Unsuccessful (did not complete): append failure explanation to the md.
