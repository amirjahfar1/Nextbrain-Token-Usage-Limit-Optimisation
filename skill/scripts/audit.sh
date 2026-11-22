#!/bin/sh
# Compact token/usage audit of the current project (read-only). Run from the project root.
D=$(cd "$(dirname "$0")/.." && pwd); S=.claude/token-optimisation
python3 "$D/scripts/report.py" --backfill 15 2>/dev/null || echo "report: n/a"
echo "(report saved to .claude/token-optimisation/report.md)"
echo; echo "== Pending expensive-session review"
[ -f "$S/pending-review" ] && head -3 "$S/pending-review" || echo "none"
echo; echo "== Guard log (reads it flagged), top 5"
[ -f "$S/guard.log" ] && cut -f3 "$S/guard.log" | sort | uniq -c | sort -rn | head -5 || echo "none"
echo; echo "== Big files (class suggestion)"
python3 "$D/scripts/bigfile.py" scan 2>/dev/null | head -8
echo; echo "== Over-limit docs/rules"
sh "$D/scripts/check-size.sh" "$D" 2>&1 | head -6; echo "(the owner's own files are information only: no split or merge without a yes)"
echo; echo "== Connectors: run /context and /mcp, list what this project does not use (rules/mcp.md M2, M5)"
