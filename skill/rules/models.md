# Model routing

Roles, not names. Names live in `config/defaults.conf` (owner-configurable, dated).

## L1 Four roles
`planner` (strongest, for plans only, gated by L6), `deep` (hard work that is not a planner request), `executor` (edits, tests, debugging, reviews), `economy` (read-only lookups).

## L2 Plan once, hand off short
The planner ends with: scope, decisions, open questions, acceptance checks. The executor receives that short plan, not the planning chat.

## L3 Do not switch model mid-slice
A model switch, and likely an effort change, can force the next request to re-read the whole conversation uncached (`session.md` S8). Switch only at a clean boundary.

## L4 Ask before substituting
If a configured model is unavailable, tell the owner and confirm a substitute first.

## L5 Match effort to the task
Low effort for lookups and clear edits; high only for design and hard debugging. Keep standard speed when saving usage.

## L6 The strongest model is gated: ask first
Before any plan, adoption or optimisation, ask the owner once: "Plan with Fable (strongest, costs more) or with the current model?" (`adoption/00-owner-questions.md`). Fable runs only on a yes, and then the owner switches (`/model`) before any reading and back after the plan; you never switch yourself. No answer means the current model. Never pick it for a subagent, the deep tier, a review or a task that merely feels hard: hard work uses `role_deep` (Opus-class) at normal effort. If a task seems to need the planner, say so in one line and ask.
