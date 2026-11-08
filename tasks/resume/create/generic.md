# ReCompile Resume for Job Role

## Inputs

- A generic job role or position from user

## Tools

Identify ADE skills pertaining to: Web browsing, PDF management, database connection (use resume-reader role if available)

## Phase 1: Analyze Role

1. Research the job role (web browsing)
   - Identify common requirements and the most sought skills for the role - distinguish hard and soft skills
   - Identify typical hard/absolute requirements and soft/ideal requirements for the role
   - Pair hard skills with abstract equivalents for later use - ex: AWS/Cloud Services, FastAPI/API Frameworks, Python-contextual/OOP or scripting or programming. Get pairs + years from `search_skills(array[...], null, 'precise')` (`--skill-mode precise`) (skill `search-skills`)
2. Scan database to identify relevant skills and direct education or training

   Look for, in order:
   1. Explicit hard matches with applicable work experience
   2. Abstract matches or comparable skills with applicable work experience
   3. Explicit or abstract matches tied to personal growth or personal projects
3. Scan pitches in database to identify the best fit. Select 1-3 that most closely align with the role.
4. Scan the DB for stored resume guidance.
5. Write a temporary MD report to the temp folder and show its contents in chat. Use concise, structured tables. Report in this order:
   1. Percentage match against common role requirements with stated reasoning
   2. Skill match chart with the same prioritizations from steps 1 and 2
   3. Applicable projects
   4. Missing skills using priorities from step 1
   5. Best fit pitches for the selected role with reasoning
6. Prompt user for resume guidance, resume template (default: first in templates folder), and cover letter guidance.

**STOP: wait for user approval before Phase 2.**

## Phase 2: Resume

Given: Guidance and feedback from user for resume creation

Output: resume as PDF and MD in the temp folder with one role-specific subfolder.

Sections, in order:

1. **Contact info** - Check database to get appropriate contact information. Include name, city, email, personal website, LinkedIn, GitHub if available.
2. **Summary** - Combine user-specified pitches and a career overview into a coherent 1-3 paragraph summary tailored to the role. Include direct years of experience for most applicable skills.
3. **Skills section** - Pick top 10 skill matches and present them in a clean table format with years of experience or (1-5) ranking depending on what best sells the skill matches.
   - Row: "<role skill> (<its yrs>) + Other <abstract equivalent>"; Years column = combined total. Ex: "AWS (2) + Other Cloud Services" | 4.
   - Add "+ Other" only if the DB has a distinct skill of the same kind; otherwise "<role skill>" | its yrs.
   - Name sub-tools or services in parentheses only when the role commonly requires them and they match db records.
4. **Work Experience** - Include all non-private-marked work experience. Each entry: top level summary (required: build from `employer.company_desc` + the summary sentence of `resume_desc`; if neither exists, flag it to the user rather than omit); top 3 most applicable line items; skills subsection with ~3 most role-applicable skills. Use explicit hard skills when they match directly, otherwise use the abstract equivalent. Ex: if role commonly requires FastAPI, list FastAPI where used; elsewhere say "web frameworks like FastAPI".
5. **Projects** - Include projects with applicable skills; omit section if none.
6. **Education, Training, Certifications** - Always include all non-private-marked `education_and_training` rows, split into three sections by `type`:
   - **Education**: bachelors, masters, phd
   - **Training**: training, training_certificate
   - **Certifications & Clearances**: certificate, clearance
   - `other`: flag to the user.

## Phase 3: Cover Letter

1. Ask user whether they want a cover letter and for guidance.
2. Draft it from best fit DB pitches plus that guidance and show it.
3. **STOP: wait for confirmation.**
4. Save it as PDF and MD in the resume files' existing temp subfolder.
