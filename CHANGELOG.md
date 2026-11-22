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
- New rules A5 (subagent model tiers) and A6 (research stays out of main chat); S3/S4/S7 updated (hand off near 50
## 0.6.0 (2026-11-23)
- Added mods/ (marketplace nextbrain-mods): handoff (500k), model-router, cache-clock, research-router, savings-proof; MODS.md maps each to its rule.
- New rules A5 (subagent model tiers) and A6 (research stays out of main chat); S3, S4, S7 updated (hand off near 50 percent, keep-warm guidance).
- Checks skip vendored mods/plugins and the token-saving-mods reference folder (git-ignored).

## 0.6.1 (2026-11-23)
- Fable gate (L6): the planner model runs only when the owner names it; deep work uses role_deep (Opus-class) at normal effort with a bounded brief and report. ADOPTION, START-HERE and adoption/02-plan no longer say "strongest model" by default.
- model-router leaves a Fable model named on the Agent call alone; never picks Fable.

## 0.6.2 (2026-11-23)
- START-HERE route 4: how an agent updates a project that already has the system (check, update, read changelog, report).
