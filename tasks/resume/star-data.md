# star-data

- Run steps 1–3 for each table below, one table at a time.
- Do not make unapproved changes.
- Avoid removing information.

## Tables

### `pitches`
Detail:
- These don't necessarily have to be STAR. They may be generalized strengths.
- Look for opportunities to improve, but don't overcritique.

### Employment history: `employer`, `employment_titles`
Detail:
- Should have 5–10 bullet points. The bullet points are the main candidate for STAR evaluations.
- Should have for 5-10 skill links.
- Ddescription should include both company details and role details

### `personal_growth`
Detail:
- Not necessarily STAR, but look for areas of improvement. Remove ambiguity, state objective, etc...

### `hardships`
Detail:
- What was done to cope or resolve?

### `projects`
Detail:
- Do they have a problem to solve?
- How was the problem addressed?
- What was the result?

## 1. Fetch
1. Using the Supabase connector, get the table's resume data.

## 2. Evaluate
1. For each entry, and for the combined table data, judge whether it follows STAR (Situation, Task, Action, Result).
2. Apply the table's detail, if any.

## 3. Report
1. Report the data in two tables, emphasizing STAR adherence:
   1. **Good:** entries that follow STAR.
   2. **Not good:** entries that do not, with a `Reasoning` column and a `Suggestion` column.
