# ReCompile Resume for Job Description

## Inputs

- Job description (jd) from user

## Tools

Identify ADE skills pertaining to: Web browsing, PDF management, database connection (use resume-reader role if available)

## Phase 1: Analyze JD

1. Scan to comprehend jd
   - Identify the primary and secondary skills stated in the jd - distinguish hard and soft skills
   - Identify the hard/absolute requirements, and soft/ideal requirements stated in the jd
   - Pair hard skills with abstract equivalents for later use - ex: AWS/Cloud Services, FastAPI/API Frameworks, Python-contextual/OOP or scripting or programming. Get pairs + years from `search_skills(array[...], null, 'precise')` (`--skill-mode precise`) (skill `search-skills`)
2. Scan database for relevant skills, education, training, certifications, and clearances. Tables:
   - Skills: (skill `search-skills`)
   - Education, training, certifications, clearances: `education_and_training` (all `type`s)
   - Work experience: `employer`, `employment_titles`
   - Projects and personal growth: `projects`, `project_skills`, `personal_growth`

   Look for, in order:
   1. Explicit hard matches with applicable work experience
   2. Abstract matches or comparable skills with applicable work experience
   3. Explicit or abstract matches tied to personal growth or personal projects
3. Scan pitches in database to identify the best fit. Select 1-3 that most closely align with the jd.
4. Scan the DB for stored resume guidance.
5. Write a temporary MD report to the temp folder and show its contents in chat. Use concise, structured tables. Report in this order:
   1. Percentage match with stated reasoning
   2. Skill match chart with the same prioritizations from steps 1 and 2
   3. Applicable projects
   4. Missing skills using priorities from the JD
   5. Best fit pitches for the selected role with reasoning
6. Prompt user for resume guidance, resume template (default: first in templates folder), and cover letter guidance.

**STOP: wait for user approval before Phase 2.**

## Phase 2: Resume

Given: Guidance and feedback from user for resume creation

Output: resume as PDF and MD in the temp folder with one JD specific subfolder. File name: `name-careertitle-company-resume.<ext>` (e.g. `ryan-montgomery-customer-platform-engineer-iii-blue-origin-resume.pdf`).

Sections, in order:

1. **Contact info** - Check database to get appropriate contact information. Include name, city, email, personal website, LinkedIn, GitHub if available.
2. **Summary** - Combine user-specified pitches and a career overview into a coherent 1-3 paragraph summary tailored to the jd. Include direct years of experience for most applicable skills.
3. **Skills section** - Pick top 10 skill matches and present them in a clean table format with years of experience or (1-5) ranking depending on what best sells the skill matches.
   - Row: "<jd skill> (<its yrs>) + Other <abstract equivalent>"; Years column = combined total. Ex: "AWS (2) + Other Cloud Services" | 4.
   - Add "+ Other" only if the DB has a distinct skill of the same kind; otherwise "<jd skill>" | its yrs.
   - Name sub-tools or services in parentheses only when the jd names them and they match db records.
   - Use the jd's exact term in the row name. When the jd term matched through a skill alias (e.g. OIDC, SAML → OAuth), name it: "OAuth 2.0 / OIDC / SAML (1)".
4. **Work Experience** - Include all non-private-marked work experience. Each entry: top level summary (required: build from `employer.company_desc` + the summary sentence of `resume_desc`; if neither exists, flag it to the user rather than omit); top 3 most applicable line items; skills subsection with ~3 most JD-applicable skills. Use explicit hard skills when they match directly, otherwise use the abstract equivalent. Ex: if jd requests FastAPI, list FastAPI where used; elsewhere say "web frameworks like FastAPI".
   - Pull each entry's skills from its `skill_links` rows; never write a skill the entry has no link for. Use the jd's spelling for those skills.
   - **Key terms go in the entry text, not just the skills line.** For each entry, intersect its linked skills with the jd terms; every match must appear (jd spelling) in that entry's summary or bullets. The skills subsection alone does not count.
   - Rewrite the summary and bullets around those terms where the DB bullet or linked skill backs it (e.g. "polling to event driven" → "event-driven architecture on AWS"; Cognizant linked to Docker/CI/CD → "deployed via Docker and CI/CD").
5. **Projects** - Include projects with applicable skills; omit section if none. Each entry: name, brief one-line description, tools, and link. Link = `projects.homepage_url` (website) whenever set; else first `source_url`.
6. **Education, Training, Certifications** - Always include all non-private-marked `education_and_training` rows, split into three sections by `type`:
   - **Education**: bachelors, masters, phd. List school, years attended, and area of study only; no degree type or completion status unless explicitly asked (see `education-incomplete.mdc`).
   - **Training**: training, training_certificate
   - **Certifications & Clearances**: certificate, clearance
   - `other`: flag to the user.
7. **Disclaimer** - Always end with a horizontal rule and this fine print (small, gray), verbatim:
   > This resume was created from a database of personal resume info selected for this role and manually reviewed before sending. Details of the generation tool are available from [github.com/Macioa/resume-and-application-toolkit](https://github.com/Macioa/resume-and-application-toolkit). Data can be explored from the chat utility at [ryanwademontgomery.com](https://ryanwademontgomery.com).

8. **Key-term check** - Before saving, list every hard skill/term from Phase 1 step 1. Each one the DB backs must appear verbatim (jd spelling) in the summary, skills table, or an entry. Show the user a table: term | where it appears | or "gap (not in DB)". Then a per-entry table: entry | linked jd terms | missing from entry text (must be empty).

## Phase 3: Cover Letter

1. Ask user whether they want a cover letter and for guidance.
2. Draft it from best fit DB pitches plus that guidance and show it.
3. **STOP: wait for confirmation.**
4. Save it as PDF and MD in the resume files' existing temp subfolder, named `name-careertitle-company-cover-letter.<ext>`.
