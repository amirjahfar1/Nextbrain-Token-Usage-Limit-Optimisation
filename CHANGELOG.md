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
