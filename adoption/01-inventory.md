# 1. Inventory and baseline (read-only)

Record findings in `.claude/token-optimisation/baseline.md` (git-ignored).

## Inventory
1. Instruction files: `AGENTS.md`, `CLAUDE.md`, nested ones, imported files. Note line counts.
2. Skills (`.agents/skills`, `.claude/skills`), rules (`.claude/rules`), slash commands.
3. Settings at every scope: `.claude/settings.json`, `settings.local.json`, user settings. Note existing hooks and permission rules.
4. MCP servers, connectors, plugins that load for this project.
5. Navigation aids: CODEMAP, code-graph tool, generated indexes.
6. Big files: `sh install.sh --scan <project>` (also finds lockfiles, generated JSON, long docs).
7. Existing token or usage rules anywhere (they are the merge targets).

## Baseline
- Owner pastes `/context` and `/usage` from a fresh session in this project.
- Run `python3 skill/scripts/cost_report.py --last` on the last few transcripts: fixed overhead, peak context, repeated reads.
- Never estimate. If a reading is missing, write "not measured".

## Output
A one-page summary: what exists, what is large, what the fixed overhead is made of.
