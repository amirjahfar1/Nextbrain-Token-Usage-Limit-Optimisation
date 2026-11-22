# 0. Ask the owner first (before reading, planning or writing anything)

Ask all of these in ONE message, each with a recommended default, then wait for the answers. Nothing is read, planned or written before they come. Ask again in every new session and every route (install, adopt, update).

1. **Plan with Fable (the strongest model, costs more) or with the current model?** Default: the current model.
   - Yes: ask the owner to run `/model <role_planner>` now, before any reading (a switch in the middle of a chat loses the cache, `rules/models.md` L3). After the plan is approved, ask them to switch back for the apply phase. You never switch models yourself.
   - No, or no answer: stay on the current model. Never pick Fable on your own.
2. Which files, skills, hooks and settings must stay exactly as they are (the will-NOT-touch list)?
3. May I install the Claude Code mods for every project on this Mac (`sh install.sh --mods`)? model-router changes subagent models. Default: not now.
4. Are the size limits advisory only (`enforce_size=0`)? Your own files are never split, merged, renamed or moved without a yes. Default: advisory only.
5. May the hooks record session cost from transcripts (SessionStart/SessionEnd), or guard only (`--hooks=guard`)? Default: guard only at first.
6. Which MCP connectors and plugins does this project really use?
7. Which 2-3 typical tasks are the before/after benchmark? Please paste `/context` from a fresh session.
8. Is it a git repo, and may I work on a branch `token-opt-adoption` with one commit per change? Default: yes.

## Definition of done
- `sh install.sh --check <project>` passes and the project's own build and tests pass.
- No owner file grew (apart from the block) and the will-NOT-touch list is unchanged (show the diff).
- Before/after on the benchmark tasks from real readings: first-request tokens, peak context, repeated reads (`rules/measure.md`).
- Rollback was tried on a copy: `--uninstall` leaves the tree as it was.

## How to measure
`/usage` is account-wide, so it cannot measure one project. Run the same 2-3 tasks before and after and read each session with `python3 <repo>/skill/scripts/cost_report.py <transcript path>`. With the Token Meter mod, its report compares before and after per request once 20 requests exist on each side.
