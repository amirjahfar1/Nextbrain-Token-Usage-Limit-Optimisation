# /token-audit: how to use it and read the report

`/token-audit` (Codex: `$token-audit`) shows where this project's tokens go and builds a running report. Read-only: it changes nothing.

## 1. Run it
- Type `/token-audit` in the project root session. Run it after a finished or expensive session, or weekly.
- First time: it back-fills up to the last 15 past sessions of this project from local transcripts, so the report is useful at once.
- Shell: `sh .agents/skills/token-optimisation/scripts/audit.sh`.

## 2. Where the data comes from
- The SessionEnd hook appends one row per finished session to `.claude/token-optimisation/sessions.jsonl` (and `sessions.tsv`). It never blocks or crashes a session.
- The report is `.claude/token-optimisation/report.md`, rebuilt on every run. Both files are local and git-ignored.
- Install check: `.claude/settings.json` must contain the three hooks (`install.sh --check` confirms).

## 3. Read the report
| Section | Means | Act on |
|---|---|---|
| Last sessions | requests, peak context, tool-result size, flags | one session far above the rest: read its drivers |
| What uses the most | share of tool results by tool | Bash very high: cap output (R3); Read high: ranges (R2) |
| Biggest single results | same command or file returning big output again and again | split, index or guard it (B3, B4) |
| Files read in full twice | repeated full reads | R4; add the file to `ranged` in the project conf |
| Suggestions | tip ids | `sh scripts/tips.sh <id>` shows the tip |

Also shown: guard log (reads the guard flagged), bigger files with a proposed class, docs over the size limit.

## 4. Flags and thresholds
- Structural flags always apply: repeated full reads, compaction, model switch, MCP-dominated results.
- Numeric flags (peak context, tool-result size, requests) start only after 10 recorded sessions, then fire above this project's own 75th percentile. No numbers are invented.
- Fixed overhead (first request input) comes from the transcript; compare it with `/context` at session start.

## 5. After the report
1. Tell the owner the top 3 drivers in short Roman Urdu, each with its tip id.
2. Propose the smallest fix: a `ranged` entry, a deny rule, a connector to disable, a shorter session plus `/handoff`.
3. Apply only after the owner says yes. Backup first, verify, then re-run `/token-audit` next week to confirm the driver shrank.
4. A flagged session also leaves `pending-review`; the next session start offers `rules/session-review.md`.

## 6. Trouble
- "No sessions recorded": hooks not installed in this project, or no session has ended yet. Use `--backfill`: `python3 scripts/report.py --backfill 15`.
- Report looks empty for a project opened from a parent folder: run from the folder where Claude Code starts (transcripts are keyed by that path).
