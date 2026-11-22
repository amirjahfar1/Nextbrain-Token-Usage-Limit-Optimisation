# Claude Code mods (installed automatically, once per Mac)

Mods are Claude Code only and install once for the whole Mac, so every project gets them with no per-project setup. The rules in `skill/` stay universal (Claude Code, Codex, others) and are still installed per project. Mods add automation on top; they never replace the rules.

Source: `mods/` (marketplace `nextbrain-mods`, six mods). Credits: `mods/NOTICE.md`.

## Install (automatic, nothing to do by hand)
`sh install.sh --auto <project>` (START-HERE route 0) also installs or updates every mod for this Mac with the Claude Code CLI (`installer/mods.sh`), but only for a brand-new or already installed project: a project with its own rules gets a dry run and no mods until the owner agrees (adoption question 3), then `sh install.sh --mods`. Mods only, no project needed: `sh install.sh --mods`. Skip with `--no-mods`. The mod list is read from `mods/.claude-plugin/marketplace.json`, so a new mod needs no script change. It checks each mod's installed version against the repo's: not installed, install; older, update; same, leave it. Running it again is safe. A mod change only reaches other Macs if its `plugin.json` and `marketplace.json` versions are bumped. The marketplace points at the folder the script ran from, so use the shared copy `~/.claude/nextbrain-token-system` (route 0) on every Mac.

## Install by hand (only if the CLI was not found)
Needs Claude Code 2.1.287+ (desktop app 2.1.286+). In Claude Code, with this repo's path:
```
/plugin marketplace add <path to this repo>/mods
/plugin install handoff@nextbrain-mods
/plugin install model-router@nextbrain-mods
/plugin install cache-clock@nextbrain-mods
/plugin install research-router@nextbrain-mods
/plugin install savings-proof@nextbrain-mods
/plugin install token-meter@nextbrain-mods
/reload-plugins
```
Then check `/plugin` that the scope is user, and try `/savings`. Update: `/plugin marketplace update nextbrain-mods`, `/reload-plugins`.

The same works from a terminal with `claude plugin marketplace add <path>/mods` and `claude plugin install <name>@nextbrain-mods` (scope user). The desktop app ships its own binary under `~/Library/Application Support/Claude/claude-code/<version>/*/claude.app/Contents/MacOS/claude`. Check with `claude plugin list` and `claude plugin validate <path>/mods`. A chat that was open before the install needs `/reload-plugins` or a new chat.

## Which mod owns which rule (one owner each, K2)
| Mod | Rules it serves | What it does | Note |
|---|---|---|---|
| handoff | S3, S7 | Offers a Refresh handoff at 500k tokens | Constant `OFFER_AT` in its `register.tsx`; lower it on a 200k window |
| model-router | A5, L3 | Haiku picks each subagent's model by tier | Tiers are Haiku, Sonnet, Opus: it never picks Fable (L6). A model named on the Agent call is left alone; only an unnamed spawn is judged. Fable ranks above deep, so moving off an inherited Fable needs confidence 0.6; a Plan subagent of a Fable parent keeps Fable. Never set `deepModel` to Fable. Never changes the main chat's model |
| cache-clock | S4, S8 | Countdown to a cold cache; opt-in `/keepwarm` | Keep warm stays off unless started |
| research-router | A6 | Keeps web research out of the main chat | Auto on big WebSearch results; `/research-router` for a brief |
| savings-proof | measure | `/savings` shows tokens the mods saved | Reads `~/.claude/mods-logs/savings.jsonl` |
| token-meter | measure, S8 | Pane with context, limits, cost, top tools, savings today; `/token-report` full report (today, 7d, 30d, all) | `python3 bin/report.py 30d` works by hand; the report compares before and after the system (indicative, needs 20 requests each side) |

Without a mod (Codex, other clients, or mod off) the rule alone applies: follow it by hand.

## Honest limits
- Checked 2026-11-23 on Claude Code 2.1.330: all six install (scope user) and validate; the first five fire their hooks in a headless run (`~/.claude/mods-logs/model-router.log`, `savings-proof.log`); token-meter also passes its own `claude plugin test` (pane and report render on terminal and desktop). Not yet seen in a real chat: the panes, a real subagent route, a handoff. Try `/savings` and `/token-meter` in a chat to confirm.
- Unlike the original pack there is no `/mods` switchboard, `input-router`, `effort-optimizer` or `efficient-browser-use`. To turn a mod off use `/plugin`.
- Haiku does the reading in model-router and research-router, so a small helper cost shows in `/savings`. Notes can be wrong: for exact work use the real tool.
- Keep this repo private: only `model-router` has a confirmed licence.
