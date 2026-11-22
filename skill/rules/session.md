# Sessions, context and cache

## S1 One slice per session
One feature slice, bug or review scope per chat. Start a fresh chat at a clean boundary.

## S2 Checkpoint before compact or clear
Write: goal, decisions, touched files, checks done, remaining work, next exact action. No secrets, no pasted logs.

## S3 Context heads-up (heuristic)
Claude Code: hand off near 50% used (owner's choice, 500k on a 1M window; the `handoff` mod offers it, see `MODS.md`). Codex Plus: warn near 60%, checkpoint near 70%. Calibrate from the real meter; never invent a percentage.

## S4 Long breaks
A break alone is weak reason to clear. Checkpoint first, then resume, compact or start fresh. Never send messages just to warm the cache. Exception: the `cache-clock` mod's opt-in `/keepwarm`, only when you will be back within about an hour (heuristic: each ping is a cache read, and about 12 to 25 pings cost as much as one cold rewrite). Longer break: let it go cold and hand off.

## S5 Keep the prefix stable
Editing instruction files, toggling MCP servers (`/mcp`), changing tools, model, effort or thinking, or adding images mid-chat can break cache reuse. Batch such changes at a boundary.

## S6 Clear between unrelated tasks
Unrelated work gets its own chat; old history is paid for on every turn.

## S7 Hand off, do not drag
`/handoff` (Codex `$handoff`) writes a checkpoint from `templates/handoff.md`. Use it at a clean boundary or when `/context` shows the chat is large; default trigger is about 50% of the window (500k on 1M), a heuristic; change it from real readings. The owner clears the chat.

## S8 Cache facts and the hit ratio
From the Anthropic prompt caching docs, checked 2026-11-23. These are API facts; Claude Code manages breakpoints itself, so treat the Claude Code effect as UNVERIFIED.
- Prefix order is tools, system, messages. A change at one level invalidates it and everything after.
- A cache read costs about 10% of normal input (about 5% on Sonnet 5.5 and Opus 5.5). Default lifetime is 5 minutes, refreshed on each use.
- Known invalidators: tool definition changes, effort or thinking changes, adding or removing images, a model switch.
- `/token-audit` shows the cache hit ratio: read / (read + write + new input). A low average over several sessions (heuristic: below about 50%) points to S5, L3 and S4.
