# Adopting this system in an existing project

Goal: cut token and usage cost WITHOUT breaking or degrading what already works. Read-only until the plan is approved.

**Phase 0: ask the owner** (`adoption/00-owner-questions.md`), first of all: Fable (strongest, costs more) or the current model for planning? Wait for the answers, then use plan mode. No reading of the project and no edits before that. Fable only on a yes (rules/models.md L6).

| Phase | Open | Output |
|---|---|---|
| 1 Inventory | `adoption/01-inventory.md` | What exists: instruction files, skills, rules, settings, hooks, MCP, navigation tools, big files |
| 2 Baseline | `adoption/01-inventory.md` (baseline section) | `/context`, `/usage` readings, transcript numbers |
| 3 Plan | `adoption/02-plan.md` | Conflict table, will-NOT-touch list, net line delta |
| 4 Apply | `adoption/03-apply-verify-rollback.md` | Dry-run, owner yes, small verified steps, rollback |

## Hard rules
- Understand before optimising: finish phases 1-3 before any write.
- Merge, never duplicate: an existing rule is edited in place, not repeated.
- Net size of each existing instruction file must not grow (apart from the short always-on block).
- Never merge, rename, move or shorten the owner's skills or rules. Propose a trim only with a yes.
- Smallest diff, one change at a time, verify each, keep a backup.
- Stop and ask the owner whenever a step could remove or change something that exists.
- Start the read guard in `log` mode; switch to `deny` only after a calibration period.
- Do not invent numbers: baseline and results come from real readings only.
