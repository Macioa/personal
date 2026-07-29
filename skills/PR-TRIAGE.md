# PR Triage

> AVOID HALLUCINATIONS, GUESSWORK, PARAPHRASING
> USE DIRECTLY QUOTED INFORMATION IN ALL TASKS
> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

Drive a feature branch to merge-ready. Use the `gh` CLI for all git/GitHub management. **Never merge** — stop at merge-ready.

## Steps

1. **Commit local changes.** Stage and commit any uncommitted work on the branch with a clear message.
2. **Review branch against main.** `git diff --stat main...HEAD`. Flag anything that doesn't belong — excess documentation, temporary/scratch test files, debug scripts, stray config — and remove it. Confirm secrets/`.env` are not tracked. Anything that isn't necessary for the feature should be removed.
3. Review branch for refactor opportunities. Prioritize code reuse, simplicity, and minimal deviation from main.
4. **Push + ensure a PR exists.** Push the branch. If no PR is open, create one (`gh pr create`). Confirm the branch is in sync with origin.
5. **Poll status checks.** `gh pr checks <n>` and `gh pr view <n> --json mergeable,mergeStateStatus,reviewDecision`. Wait for checks to finish.
6. **Merge conflicts.** If `CONFLICTING`: fix simple/mechanical conflicts (e.g. lockfiles, migration renumbers, import ordering). **Halt and prompt the user** for severe/semantic conflicts.
7. **Review, fix, resolve PR issues.** Pull review comments (`gh api .../pulls/<n>/comments`; GraphQL `reviewThreads` for resolved/outdated state). Fix legitimate findings, push, and resolve the threads. Re-run failing checks.
8. **Repeat** steps 4–6 until the PR is merge-ready (checks green, mergeable, no open blocking review threads).
9. **Stop.** Report merge-ready status. Do not merge.

