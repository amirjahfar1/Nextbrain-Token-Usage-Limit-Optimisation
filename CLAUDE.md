# CLAUDE.md

Goal: only upgrade and optimise this token-usage optimisation system for Claude (and Codex). Nothing else.

## Orientation (read in this order, stop early)
1. `MAP.md`: which file to open when. Open one child file per situation, never whole folders.
2. `START-HERE.md` for agent rules; `README.md` for usage.
3. Source of truth for tips: `skill/tips/registry.tsv` (never hand-edit generated tips; run `sh skill/scripts/gen-tips.sh`).

## Rules
- Files stay English and small (limits in `skill/config/defaults.conf`). Reply to the owner in short Roman Urdu.
- Keep the repo generic: no secrets, no personal or project details.
- Only change the system when it makes it better; never risk breaking what works.
- Small/minor changes (wording, typos, tiny tips, small fixes): do directly.
- Major changes (new/removed/reworked rules, hooks, installer, scripts, registry structure, anything that alters behaviour): always ask the owner first and wait for a yes.
- Never weaken or delete an existing rule/hook without the owner's yes.
- Before finishing any change: `sh scripts/check-repo.sh` must pass.
- Each change: bump `VERSION`, add a `CHANGELOG.md` entry (one line, same style).
- Instructions travel with the change. When a mod, command, script or flow is added or changed, update in the SAME change: `MODS.md` (what it is, how it installs), `START-HERE.md` and `README.md` if the owner-facing steps change, and the automatic flow (`installer/auto.sh`, `installer/mods.sh`). Goal: on any other PC, an agent given this repo does everything with no manual step. A new mod goes in `mods/.claude-plugin/marketplace.json` (its version equal to its `plugin.json`) and in `MODS.md`; `scripts/check-repo.sh` fails if not.
- Test the install path with a scratch `CLAUDE_CONFIG_DIR`, never the owner's real config.
- Any change to `install.sh`, `installer/`, `skill/hooks/` or `skill/scripts/`: run `bash tests/installer/run_all.sh` (about 4 minutes, 44 scenarios, works in its own folder, needs no network) and it must end with `failed 0`. Add a scenario for every new defect.
- Never push a change that makes the installer write into a project that has its own rules without the owner's yes.

## "Update kar do" workflow (GitHub, via global GitHub MCP)
When the owner says "update kar do" (or similar):
1. Run `sh scripts/check-repo.sh`; fix failures first.
2. Bump `VERSION` and add the `CHANGELOG.md` entry.
3. Push to `amirjahfar1/Nextbrain-Token-Usage-Limit-Optimisation` on `main`. Small change (a few small files): global GitHub MCP (`mcp__github__push_files`, load via ToolSearch). Bulk change (many or big files, e.g. `mods/`): `git commit` + `git push` instead, because the MCP needs every file's full text sent as tokens. Commit as the author of earlier commits (`git log -1 --format=%an,%ae`) with `-c user.name -c user.email`; do not store the owner's personal email.
4. Commit message style: `vX.Y.Z: short summary` (see `git log`).
5. Report in one or two lines what was pushed. Do not push without this trigger.
