# Nextbrain Token | Usage Limit Optimisation

A portable system that lowers token use and protects usage limits for Claude Code and Codex. Hand an agent this repo (or its GitHub URL) and it installs everything itself.

## What is inside
| Part | Where | What it does |
|---|---|---|
| Rules | `skill/rules/` | Small on-demand rule files (reading, requests, models, sessions, subagents, MCP, big files). Only a 5-line block is always loaded |
| Tips | `skill/tips/registry.tsv` | One registry; `/tips` prints every optimisation, generated from it |
| Guards and tools | `skill/hooks/`, `skill/scripts/` | Big-file guard, big-file index and shard tools, expensive-session review, cost reports |
| Claude Code mods | `mods/` | Ten mods installed once per Mac, for every project: handoff, model-router, cache-clock, research-router, savings-proof, token-meter, input-router, effort-optimizer, efficient-browser-use, mods. See `MODS.md` |
| Installer | `install.sh`, `installer/` | Safe install, update and uninstall; refuses before writing, never overwrites a project's own rules |
| Adoption | `ADOPTION.md`, `adoption/` | Safe path for a project that already has its own rules |

Rules work in any client (Claude Code, Codex, others). Mods are Claude Code only and add automation on top.

## Use it
Tell the agent in any project: "Follow `<path to this repo>/START-HERE.md`", or give it the GitHub URL, or say "token system updated". It keeps one copy in `~/.claude/nextbrain-token-system` and runs `sh install.sh --auto <project>`. Manual:

```sh
sh install.sh --dry-run /path/to/project
sh install.sh /path/to/project
sh install.sh --check /path/to/project
```

Needs `sh` and `python3` (stdlib only). Works offline after install.

## Commands
Slash commands in a chat:

| Command | Does |
|---|---|
| `/tips`, `$tips` | All token tips, or help choosing model and context |
| `/token-audit` | Usage and cost audit of the project |
| `/handoff`, `/fresh` | Checkpoint this chat, or move the work to a fresh chat |
| `/savings`, `/token-meter`, `/token-report` | What the mods saved; live meter; full report |
| `/mods` | List mods, turn each on or off (`/mods off <name>`) |
| `/model-router`, `/research-router` | Subagent model picks; cheap web research brief |
| `/cacheclock`, `/keepwarm` | Prompt-cache countdown; optional keep-warm ping |

Installer flags, maintenance scripts and every command in two lines each: `COMMANDS.md`.

## Maintain
`sh scripts/check-repo.sh` (size limits, tips sync, links, secret patterns) must pass before any change. Add a tip: one registry row plus a `## ID` heading in its rule file, then `sh skill/scripts/gen-tips.sh`. Reading order for contributors: `MAP.md`, `CLAUDE.md`.

Keep the repo private: it holds no secrets or personal data. Model names are owner-configurable in `skill/config/defaults.conf`.
