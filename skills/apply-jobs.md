# Apply Jobs

> AVOID HALLUCINATIONS, GUESSWORK, PARAPHRASING
> USE DIRECTLY QUOTED INFORMATION IN ALL TASKS
> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

1. For each job md in `temp/job_posts`:
   - Check Supabase for an existing login for that portal.
   - If none exists: register, then save the login to Supabase (`logins`).

2. Proceed through the application using personal information from Supabase (`personal_info_and_docs`).
   - Do not enter any information without a direct Supabase reference.
   - No fabrications, hallucinations, or uncertainty.
   - If necessary information is not found: abort and process as failure (step 4 unsuccessful).

3. When the process has ended, log the application in Supabase per `supabase/migrations/` (`applications`; link login via `application_logins` when applicable).

4. Outcome:
   - Successful (confirmed submitted): remove the job posting md from `temp/job_posts`.
   - Unsuccessful (did not complete): add a section at the bottom of the md with the failure explanation.
