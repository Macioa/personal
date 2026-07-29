# Email Process

1. Before performing these actions connect to my supabase project with the supabase mcp, and examine my available personal info.
2. Then scan any documents provided in the info folder.

> Use this information to avoid hallucinations and mistakes. Nothing should be assumed or hallucinated. Do not share private or inappropriate information.

3. Connect to my Gmail using Composio.
4. Scan my `temp/mail` folder.
5. For each md in the folder, perform the requested task (send the email, replace the missing text, add the attachment, create the folder, etc...).
   - If the md was processed successfully, remove the md from the folder and move the mail item out of the inbox and into the appropriate folder.
   - If the md process failed, add a failure report to the md including number of failures and suspected reasoning for failures.
6. After completion, report the success percentage, total success/fails, and list the failed items with short answer styling.
