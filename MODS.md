# Claude Code mods (optional, install once)

Mods are Claude Code only and install once for the whole Mac, so every project gets them with no per-project setup. The rules in `skill/` stay universal (Claude Code, Codex, others) and are still installed per project. Mods add automation on top; they never replace the rules.

Source: `mods/` (marketplace `nextbrain-mods`, five mods). Credits: `mods/NOTICE.md`.

## Install (once)
Needs Claude Code 2.1.287+ (desktop app 2.1.286+). In Claude Code, with this repo's path:
```
/plugin marketplace add <path to this repo>/mods
/plugin install handoff@nextbrain-mods
/plugin install model-router@nextbrain-mods
/plugin install cache-clock@nextbrain-mods
/plugin install research-router@nextbrain-mods
/plugin install savings-proof@nextbrain-mods
/reload-plugins
```
Then check `/plugin` that the scope is user, and try `/savings`. Update: `/plugin marketplace update nextbrain-mods`, `/reload-plugins`.

## Which mod owns which rule (one owner each, K2)
| Mod | Rules it serves | What it does | Note |
|---|---|---|---|
| handoff | S3, S7 | Offers a Refresh handoff at 500k tokens | Constant `OFFER_AT` in its `register.tsx`; lower it on a 200k window |
| model-router | A5, L3 | Haiku picks each subagent's model by tier | Tiers are Haiku, Sonnet, Opus: it never picks Fable (L6). A Fable model only inherited from the parent is moved down; one named on the Agent call is left alone. Never set `deepModel` to Fable. Never changes the main chat's model |
| cache-clock | S4, S8 | Countdown to a cold cache; opt-in `/keepwarm` | Keep warm stays off unless started |
| research-router | A6 | Keeps web research out of the main chat | Auto on big WebSearch results; `/research-router` for a brief |
| savings-proof | measure | `/savings` shows tokens the mods saved | Reads `~/.claude/mods-logs/savings.jsonl` |

Without a mod (Codex, other clients, or mod off) the rule alone applies: follow it by hand.

## Honest limits
- Not tested in this repo: install and try each mod once, then run `/savings` to confirm it counts.
- Unlike the original pack there is no `/mods` switchboard, `input-router`, `effort-optimizer` or `efficient-browser-use`. To turn a mod off use `/plugin`.
- Haiku does the reading in model-router and research-router, so a small helper cost shows in `/savings`. Notes can be wrong: for exact work use the real tool.
- Keep this repo private: only `model-router` has a confirmed licence.
