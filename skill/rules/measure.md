# Measuring

## X1 Baseline and after
Record `/context` and `/usage` at session start and end in `.claude/token-optimisation/baseline.md`. Never invent a reading.

## X2 Fixed overhead
The first request's input side in the transcript is the fixed overhead (system prompt, tools, instruction files, MCP). `scripts/session_cost.py` prints it.

## X3 Keep only what saves
After any optimisation, compare with the baseline. Revert a change that does not reduce overhead or cost.
