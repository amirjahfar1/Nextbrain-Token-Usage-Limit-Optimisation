# Commands

Everything you can run in this system, grouped by where it runs.

## Slash commands (Claude Code mods)
| Command | Description |
|---|---|
| `/mods` | Lists every mod and whether it is on or off. `/mods off <name>`, `/mods on <name>`, `/mods on all` change it in every chat |
| `/savings` | Opens Savings Proof: tokens the mods saved today and in this chat |
| `/token-meter` | Opens the Token Meter pane: context, limits, cost, top tools, savings today |
| `/token-report` | Full report: sessions, tokens, cache hit, measured savings, before and after the system |
| `/handoff` | Writes a handoff of this chat now; copy it or start a new chat with it |
| `/fresh` | Shows the Refresh panel to move this work to a fresh chat |
| `/cacheclock` | Shows or hides the cache countdown (`hide`, `demo`, `auto`) |
| `/keepwarm` | Pings the cache 45 s before it goes cold; off by default, `/keepwarm off` stops it |
| `/model-router` | Haiku picks each subagent's model; shows picks and saving, `pane` opens the pane |
| `/research-router` | A cheap worker does web research and returns a short brief with sources; `deep` uses subagents |

input-router, effort-optimizer and efficient-browser-use have no command: they run by themselves and `/mods off <name>` stops them.

## Skill commands (every project, Claude and Codex)
| Command | Description |
|---|---|
| `/tips`, `$tips` | Prints every token and usage tip, or helps pick a model and reduce context |
| `/token-audit` | Audits fixed overhead, last session, big files, guard log and unused connectors |
| `/handoff`, `$handoff` | Writes a checkpoint so a fresh chat continues the task |

## Installer (`sh install.sh ...`)
| Flag | Description |
|---|---|
| `--auto <project>` | Chooses update, install or dry run, then installs the mods |
| `--dry-run <project>` | Shows what would be written; changes nothing |
| `<project>` | Installs into the project after safety checks |
| `--check <project>` | Verifies the install |
| `--update` | Moves the install to the new version; local edits survive |
| `--uninstall` | Removes only what `installed.json` recorded |
| `--scan` | Finds rules and settings a project already has |
| `--mods` | Installs or updates only the Claude Code mods |
| `--no-mods` | Skips the mods |
| `--hooks=<choice>`, `--force`, `--allow-subdir` | Pick hooks mode; override a refusal; allow a git subfolder |

## Maintenance scripts
| Script | Description |
|---|---|
| `sh scripts/check-repo.sh` | Repo self-check: sizes, tips, links, secrets, hook test |
| `sh scripts/check-size.sh`, `sh skill/scripts/check-size.sh` | Fail on a file over its size limit |
| `sh skill/scripts/tips.sh` | Prints tips by area: `--all`, area letter or id |
| `sh skill/scripts/gen-tips.sh` | Rebuilds the tips block from the registry; `--check` only checks |
| `sh skill/scripts/audit.sh` | Short read-only token audit of a project |
| `sh skill/scripts/update.sh [project]` | Updates a project from its source repo |
| `python3 skill/scripts/bigfile.py scan\|index\|get\|split-md` | Index and shard big files so they are never read whole |
| `python3 skill/scripts/cost_report.py <transcript>\|--last` | Short report on an expensive session |
| `python3 skill/scripts/report.py` | Cumulative usage report (`report.md`) |
| `python3 mods/plugins/token-meter/bin/report.py 30d` | Token Meter report by hand |
| `bash tests/installer/run_all.sh` | 44 installer scenarios (about 4 minutes); must end `failed 0` |
