# Expensive-session review

A SessionEnd hook records every session. Flagged sessions leave `.claude/token-optimisation/pending-review`; the next SessionStart tells the agent to offer this review.

## V1 Run the report
`python3 scripts/cost_report.py <transcript>` (or `--last`). Output is at most 15 lines: verdict, five numbers, top 3 drivers, up to 3 suggestions.

## V2 Present and map
Tell the owner in Roman Urdu what drove the cost. Each suggestion maps to a tip id (for example repeated reads -> R4, big result -> B3, MCP share -> M2).

## V3 Apply only with a yes
Smallest diff: a deny rule, a `bigfiles` entry, an MCP disable, a trimmed instruction line. Backup first, verify, then delete `pending-review`.

## V4 Calibrating
Under 10 recorded sessions no numeric flag is raised; only structural flags (repeated full reads, guarded read, compaction, model switch) apply.

## V5 Learn
If the review exposes a new lesson, add a registry row and child heading (`scripts/gen-tips.sh --check`).

## V6 Audit on demand
`/token-audit` (Codex `$token-audit`) runs `scripts/audit.sh`: last-session cost, pending review, guard log, big files, over-limit docs, connector reminder. Read-only.
