# START HERE (agent entry)

This repo is a token and usage-limit optimisation system for AI coding agents (Claude Code, Codex). Follow it; do not skim every file.

Pick ONE route:

1. **Existing project (default when unsure):** open `ADOPTION.md` first. Understand the project, plan in plan mode (the planner model only if the owner names it), change nothing until the owner approves.
2. **Brand-new project:** `sh install.sh --dry-run <project>`, show the owner, then `sh install.sh <project>` and `--check`.
3. **Already installed, daily use:** the project's `.agents/skills/token-optimisation/SKILL.md`. `/tips` or `$tips` prints every tip.
4. **Already installed, owner says update:** `sh <this repo>/install.sh --check <project>`. If it says "update available", run `--update <project>`, then `--check` again. Read `CHANGELOG.md` from the project's old version (`<project>/.agents/skills/token-optimisation/VERSION`) to the new one and tell the owner what changed in 3 lines. Files the project edited are kept ("kept locally edited"): list them and ask before overwriting. Project overrides in `.agents/token-optimisation.conf` are never touched. Claude Code mods are separate (`MODS.md`).

Rules for you:
- Open one child file per situation, never the whole repo.
- Never delete or weaken an existing rule, hook or connector without the owner's yes.
- Reply in short Roman Urdu when the owner writes Roman Urdu. Files stay English.
- When you optimise a project and learn something universal, feed it back here (`skill/rules/core.md` K6): generic only, no project details.
- No file here is big (limits in `skill/config/defaults.conf`). Keep it so: `sh scripts/check-repo.sh`.
