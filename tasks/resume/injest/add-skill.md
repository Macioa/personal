# Add Skill

> STORE ONLY WHAT THE USER STATES OR ANSWERS WHEN PROMPTED.
> NO EMBELLISHMENT, HALLUCINATION, ASSUMPTION, OR PARAPHRASING.
> IF ANYTHING IS MISSING OR UNCLEAR, ASK THE USER OR PROPOSE TO THE USER.
> PROMPT THE USER ONE ROW AT A TIME. WAIT FOR AN ANSWER BEFORE THE NEXT.

1. Prompt for: name, desc, type, skill_group, private. For skill_group, show existing values (`SELECT DISTINCT skill_group FROM skills`) and propose one; the user confirms.
2. Prompt for the titles, employers, education, and growth to link; link only the rows the user confirms.
3. Show the rows and insert after the user confirms.
