# Changelog

## 0.1.0 (2026-11-21)
- First release: rules, tips registry, read guard, big-file tools, session cost review, installer, adoption guide.
- Built from the App Starter Kit usage tips plus review fixes (reading discipline, big-file guards, one rough-request protocol, MCP overhead, subagents, measurement).

## 0.1.1 (2026-11-21)
- mcp.md verified against docs: per-project /mcp toggle, bare-name deny removes tools from context.

## 0.2.0 (2026-11-21)
- Added `/token-audit` command (read-only audit) and MAP.md (which file to open when).

## 0.3.0 (2026-11-21)
- Added `/handoff` command and template; selective install (`--hooks=all|guard|none`, `enforce_size=0`); adoption notes (selective adoption, transcript policy, JSON trap); planner model only when the owner names it.

## 0.3.1 (2026-11-21)
- split-md packs small sections into ~5 KB shards and fixes relative links. Rule: docs read by line range are class `ranged`, not split.

## 0.4.0 (2026-11-21)
- Cumulative usage report: sessions.jsonl per session, report.py builds report.md (what uses the most, repeat offenders, suggestions); /token-audit runs it; --last now scopes to the current project.

## 0.4.1 (2026-11-21)
- Added guides/token-audit.md: how to run /token-audit, where data comes from, how to read and act on the report.

## 0.4.2 (2026-11-21)
- tips.sh groups each area once (no repeated headings).

## 0.4.3 (2026-11-21)
- Rule K6: universal lessons from any project are fed back to this repo, generic only.

## 0.5.0 (2026-11-23)
- Cache facts (S8) from the prompt caching docs; S5 and L3 name more cache invalidators; /token-audit shows cache hit ratio.

## 0.6.0 (2026-11-23)
- Added mods/ (marketplace nextbrain-mods): handoff (500k), model-router, cache-clock, research-router, savings-proof; MODS.md maps each to its rule.
- New rules A5 (subagent model tiers) and A6 (research stays out of main chat); S3, S4, S7 updated (hand off near 50 percent, keep-warm guidance).
- Checks skip vendored mods/plugins and the token-saving-mods reference folder (git-ignored).

## 0.6.1 (2026-11-23)
- Fable gate (L6): the planner model runs only when the owner names it; deep work uses role_deep (Opus-class) at normal effort with a bounded brief and report. ADOPTION, START-HERE and adoption/02-plan no longer say "strongest model" by default.
- model-router leaves a Fable model named on the Agent call alone; never picks Fable.

## 0.6.2 (2026-11-23)
- START-HERE route 4: how an agent updates a project that already has the system (check, update, read changelog, report).

## 0.7.0 (2026-11-23)
- install.sh --auto: one command decides update (with changelog since the project's version), install (new project) or dry run (project with its own rules).
- skill/scripts/update.sh: a project pulls the source into ~/.claude/nextbrain-token-system and runs --auto; the 6th line of the always-on block triggers it on "token system updated". SOURCE file records the repo URL (credentials stripped).
- START-HERE route 0: give any agent the GitHub URL and it does the rest.

## 0.8.0 (2026-11-23)
- New mod token-meter (nextbrain-mods): Token Meter pane (context, five hour and seven day limits, cost, top tools, savings today) and a Full report button; /token-report shows sessions, input, output, cache hit, measured savings (tokens and %), by day, model, project and tool for today, 7d, 30d or all time; report.py also writes a markdown report file.

## 0.9.0 (2026-11-23)
- installer/mods.sh: installs or updates every mod in mods/ with the Claude Code CLI (idempotent; list read from marketplace.json). install.sh --auto runs it; --mods does only that; --no-mods skips.
- check-repo.sh fails when a mod is missing from MODS.md or its version differs from marketplace.json. CLAUDE.md: instructions must be updated in the same change as any mod or flow.

## 0.10.0 (2026-11-23)
- mods.sh checks each mod's installed version (install record) against the repo's: install when missing, update when older, leave when current; prints one line per mod.
- token-meter 0.2.0: "Is the system paying off?" before/after analysis per request (cost, fresh input, tool output, peak context, cache hit, compactions) with an indicative saving in dollars and tokens, mods-era comparison and guard counts; needs 20 requests per side; shown in the report pane, the markdown file and the Today card.

## 0.11.0 (2026-11-23)
- Installer rewritten after an adversarial audit (44 scenarios, tests/installer/run_all.sh): refuses before writing on bad settings, missing python3, bad --hooks, subfolder or home folder, unmanaged skill; markers match whole lines; the block is replaced in place and the original settings restored byte for byte; uninstall removes only what installed.json recorded; local edits survive every update; no downgrade; hooks fail open; entry file is CLAUDE.md when Claude Code needs it.
- --auto never installs into a project with its own rules (wider detection of the project's own settings, commands, agents and rule files) and then touches no mods.
- New step 0 for every route: ask the owner "Fable or the current model?" (adoption/00-owner-questions.md, L6); inventory cheaply; git-branch rollback; definition of done; rules R2, R4, K1-K3, K6, B6 stop pushing quality loss onto owner files.
- Mods: mods.sh leaves disabled mods alone and re-points the marketplace safely; update.sh trusts only the owner's repo and shows new commits; model-router 0.6.1 respects named models and ranks Fable above deep; token-meter 0.3.0 counts subagent transcripts (reports were undercounting), uses INSTALLED_AT, quick mode, and fixes crashes.

## 0.12.0 (2026-11-23)
- Mods: four new (input-router, effort-optimizer, efficient-browser-use, /mods switchboard), all no-model-call; marketplace and MODS.md updated, install stays automatic.

## 0.12.1 (2026-11-23)
- Docs: README rewritten; new COMMANDS.md lists every command, flag and script.

## 0.14.0 (2026-11-23)
- Routing map lists every instruction and doc file (any folder, skills, commands) with its shards when a big file was split; long lists go to `ROUTES/` children.
