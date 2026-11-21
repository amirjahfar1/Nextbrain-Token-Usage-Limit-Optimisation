# 2. Plan with the strongest model

Plan mode, no edits. Produce a short plan the owner can approve.

## Conflict table
One row per existing rule that overlaps this system.

| Existing rule (file:line) | Ours (tip id) | Decision |
|---|---|---|
| e.g. "always plan, wait for yes" | Q1/Q2 | keep / replace line in place / merge |

Decisions: **keep** (existing wins, drop ours), **replace line** (edit the existing line, no duplicate), **merge** (one combined line). Never leave both.

## Plan contents
1. Changes, in order, each with its tip ids and expected effect on the baseline.
2. Net line delta per existing instruction file (must be zero or negative, except the block).
3. A **will NOT touch** list (existing hooks, rules and settings that stay exactly as they are).
4. Risks: deny rules that hit files a workflow reads, hooks on the same events, managed settings.
5. Verification per change and the rollback for each.

## Stop and ask
Existing hooks on the same events; invalid settings JSON; managed settings; a rule that would be deleted; a deny rule that would block a workflow; any failing check.
