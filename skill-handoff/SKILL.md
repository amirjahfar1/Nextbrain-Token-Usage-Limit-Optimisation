---
name: handoff
description: "Write a checkpoint so a fresh chat can continue the task. Use for /handoff, $handoff, before /clear or /compact, or when context is large."
---

Fill `.agents/skills/token-optimisation/templates/handoff.md` from this chat and save it to `.claude/token-optimisation/handoff.md` (git-ignored, at most about 120 lines). Facts and decisions only: no secrets, no pasted logs, no file dumps. Mark unverified items. Tell the owner the path and that a fresh chat should start with "Read the handoff file". Never clear the chat yourself; the owner decides.
