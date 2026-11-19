# JD Requirements

1. JD: `<repo path>/temp/applications/[company-role]/temp/original_jd.md`. Make temp md: `jd_requirements.md`, same folder.
2. Scan JD for Primary (must have) and Secondary (nice to have): job skills, soft skills, requirements. Options listed either/or in JD ("X, Y, or Z") go in same tier. Add to md, format:

```
**Name**

***Primary***

[list]

***Secondary***

[list]
```

One block per category; `**Name**` = `Job skills`, `Soft skills`, `Requirements`. Empty list: `- None`.

3. Job skills: mark each item `skillname - explicit` or `skillname - abstract`.
   - Explicit: specific tool (React, Python, AWS).
   - Abstract: everything else (front end framework, cloud services, programming languages).
   - One item per named tool: split "X or Y" / "X, Y, or Z" into separate explicit items (same tier).
   - Abstract names: 2-4 word canonical noun phrase, no parentheticals or examples (e.g. `AI coding assistants`, not `AI-assisted development tools (code generation, ...)`).
4. Soft skills and other requirements: plain line, no tag.
