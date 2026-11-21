# MCP, connectors and plugins

## M1 Measure the overhead
Tool names and server instructions sit in context every turn. Check `/context` at session start and record it (`measure.md`).

## M2 Disable what a project does not use
Ask the owner, then disable unused servers/connectors per project. Setting names seen in Claude Code docs: `disabledMcpjsonServers`, `deniedMcpServers`, `disableClaudeAiConnectors`, `enabledPlugins`. Confirm exact semantics in the current docs before applying.

## M3 Prefer a local CLI
A local CLI (git, gh, package manager) beats a connector for routine queries. Use a connector only for data or actions the CLI lacks.

## M4 Personal choices stay personal
Put personal enable/disable choices in `.claude/settings.local.json`, not in committed settings.
