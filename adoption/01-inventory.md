# 1. Inventory and baseline (read-only)

Keep findings in the chat (or a scratch folder outside the project). Nothing is written into the project before the owner approves the plan.

## Inventory cheaply (40-50 skills, hundreds of files)
Do not open every file. Count first, open only what the counts flag:
- `find . -name SKILL.md -not -path '*/node_modules/*' | xargs wc -l | sort -n | tail -60` for skill sizes.
- `head -6` of each SKILL.md (the frontmatter) for what is always loaded.
- `rg -l -i 'token|context|usage|model' .claude .agents AGENTS.md CLAUDE.md` for existing token rules (the merge targets).
- `/context` for the always-loaded share; `sh install.sh --scan <project>` for big files.
- Hand one broad sweep to a single Explore subagent and keep only its conclusion (rules/subagents.md A1).

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
- Run `python3 <repo>/skill/scripts/cost_report.py <transcript path>` on named past sessions of this project (not `--last`: it may pick the running audit): fixed overhead, peak context, repeated reads.
- Never estimate. If a reading is missing, write "not measured".

## Output
A one-page summary: what exists, what is large, what the fixed overhead is made of.
