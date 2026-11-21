#!/bin/sh
# Compact token/usage audit of the current project (read-only). Run from the project root.
D=$(cd "$(dirname "$0")/.." && pwd); S=.claude/token-optimisation
echo "== Last session (fixed overhead, peak context, drivers)"
python3 "$D/scripts/cost_report.py" --last 2>/dev/null | head -9 || echo "n/a"
echo; echo "== Pending expensive-session review"
[ -f "$S/pending-review" ] && head -3 "$S/pending-review" || echo "none"
echo; echo "== Recorded sessions: $( [ -f $S/sessions.tsv ] && echo $(( $(wc -l < $S/sessions.tsv) - 1 )) || echo 0 ) (thresholds start at 10)"
echo; echo "== Guard log (reads it flagged), top 5"
[ -f "$S/guard.log" ] && cut -f3 "$S/guard.log" | sort | uniq -c | sort -rn | head -5 || echo "none"
echo; echo "== Big files (class suggestion)"
python3 "$D/scripts/bigfile.py" scan 2>/dev/null | head -8
echo; echo "== Over-limit docs/rules"
sh "$D/scripts/check-size.sh" .agents .claude docs AGENTS.md CLAUDE.md 2>&1 | head -6
echo; echo "== Connectors: run /context and /mcp, list what this project does not use (rules/mcp.md M2, M5)"
