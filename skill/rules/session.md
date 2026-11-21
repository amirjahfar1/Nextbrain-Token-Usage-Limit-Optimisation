# Sessions, context and cache

## S1 One slice per session
One feature slice, bug or review scope per chat. Start a fresh chat at a clean boundary.

## S2 Checkpoint before compact or clear
Write: goal, decisions, touched files, checks done, remaining work, next exact action. No secrets, no pasted logs.

## S3 Context heads-up (heuristic)
Claude Max: warn near 65% used, checkpoint near 75%. Codex Plus: warn near 60%, checkpoint near 70%. Calibrate from the real meter; never invent a percentage.

## S4 Long breaks
A break alone is weak reason to clear. Checkpoint first, then resume, compact or start fresh. Never send messages just to warm the cache.

## S5 Keep the prefix stable
Editing instruction files, tool setup or model mid-chat can break cache reuse. Batch such changes at a boundary.

## S6 Clear between unrelated tasks
Unrelated work gets its own chat; old history is paid for on every turn.
