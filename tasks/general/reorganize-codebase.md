# reorganize-codebase

## 1. Scan
1. Scan the codebase, skipping git-ignored directories, for inconsistencies:
   - Case style (kebab, snake, camel)
   - Plural vs singular folders
   - Same thing named differently in different places
   - Inconsistently located files
   - Duplicated folders or concerns
   - Duplicated tasks or code
   - Unused directories and files (empty or `.gitkeep`-only, unreferenced anywhere in the repo)

## 2. Resolve
1. Present all discrepancies to the user in one table and prompt for their preferred action on each.
2. Apply approved renames/moves with `git mv`, and update references to each renamed file in the same step.
