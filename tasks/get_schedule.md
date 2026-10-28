# Get Schedule

DB only. No calendar/Composio.

- Read: `select * from get_day_overview('<date>'[, true])`. `true` adds notes.
- Move/edit: `update todolist set target_date = ...`. Check current value first; show row, get yes.
