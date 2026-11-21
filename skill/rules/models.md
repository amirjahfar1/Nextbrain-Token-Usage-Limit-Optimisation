# Model routing

Roles, not names. Names live in `config/defaults.conf` (owner-configurable, dated).

## L1 Three roles
`planner` (strongest, for plans only), `executor` (edits, tests, debugging, reviews), `economy` (read-only lookups).

## L2 Plan once, hand off short
The planner ends with: scope, decisions, open questions, acceptance checks. The executor receives that short plan, not the planning chat.

## L3 Do not switch model mid-slice
A model switch can force the next request to re-read the whole conversation uncached. Switch only at a clean boundary.

## L4 Ask before substituting
If a configured model is unavailable, tell the owner and confirm a substitute first.

## L5 Match effort to the task
Low effort for lookups and clear edits; high only for design and hard debugging. Keep standard speed when saving usage.
