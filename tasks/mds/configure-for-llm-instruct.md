# configure-for-llm-instruct

**Input:** an md skill (target).

## 1. Reformat for LLM instruction
1. Rewrite the target as LLM instructions, optimized for LLM guidance.
2. Split into segments of numbered tasks with substeps.
3. Give the user suggestions to improve the task's effectiveness.

## 2. Fix skill references and registration
1. Replace every skill reference with a hard link to its source md.
2. Ensure the skill is registered for each appropriate ADE:
   - Claude: `.claude/skills/<name>/SKILL.md` wrapper pointing to the source md.
   - Cursor: `.cursor/rules/<name>.mdc` (`alwaysApply: false`) pointing to the source md.

## 3. Compress
1. After edits are complete, run [refactor-and-reduce](../general/refactor-and-reduce.md) on the target.
2. Show the user the changes and get approval before applying them.

## 4. Final scan
1. Confirm the task flow and output are unchanged from the original.
