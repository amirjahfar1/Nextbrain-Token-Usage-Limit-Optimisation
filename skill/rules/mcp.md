# MCP, connectors and plugins

Checked against the Claude Code docs on 2026-11-21. Items marked UNVERIFIED must be tested before relying on them.

## M1 Measure the overhead
Tool names and server instructions sit in context every turn. Check `/context` at session start and record it (`measure.md`).

## M2 Disable what a project does not use (owner approves each)
- `/mcp` toggle: works per project and persists in `~/.claude.json` under that project path, not in the repo. It covers user-scope servers and claude.ai connectors (listed by display name, e.g. "claude.ai Slack"). Re-enable from `/mcp`.
- Project `.mcp.json` servers: `disabledMcpjsonServers` rejects them in any settings file. UNVERIFIED example: `{"disabledMcpjsonServers": ["name"]}`.
- All claude.ai connectors at once: `disableClaudeAiConnectors: true`. UNVERIFIED whether one connector can be targeted.
- Plugins: `enabledPlugins` per scope. UNVERIFIED example: `{"enabledPlugins": {"name@marketplace": false}}`.
- After editing, run `/status` and `/context` to confirm the overhead dropped.

## M3 Prefer a local CLI
A local CLI (git, gh, package manager) beats a connector for routine queries. Use a connector only for data or actions the CLI lacks.

## M4 Personal choices stay personal
Put personal enable/disable choices in `.claude/settings.local.json`, not in committed settings.

## M5 Deny by bare server name
In `permissions.deny`, a bare `mcp__<server>` (or `mcp__*`) removes the tools from context entirely. A scoped rule only blocks matching calls. Example: `{"permissions": {"deny": ["mcp__github"]}}`. Whether `mcp__<server>__*` also removes them is UNVERIFIED.
