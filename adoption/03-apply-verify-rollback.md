# 3. Apply, verify, roll back

Only after the owner approves the plan.

## Before the first change
Work on a branch: `git switch -c token-opt-adoption`, one commit per change. Rollback then is `git revert` or `git switch -`. Not a git repo: copy every file you will touch into `.claude/token-optimisation/backups/` first.

## Apply
1. `sh install.sh --dry-run <project>` and show the owner the list.
2. Owner says yes. Then `sh install.sh <project>`. It backs up AGENTS.md/CLAUDE.md and settings, vendors the skill, adds the block, and merges settings additively (existing keys, hooks and deny rules are kept).
3. Apply plan edits (conflict table) one at a time, smallest diff.
4. Guard stays in `log` mode.

## Verify after each change
- `sh install.sh --check <project>`: tips in sync, size limits, hooks present, guard smoke test.
- The project's own checks (build, tests, lint) still pass.
- Existing hooks still fire; open a normal task and confirm nothing was blocked.

## Calibrate
After about 10 real sessions `sessions.tsv` has history. Read `guard.log`; for every blocked-or-logged read ask whether a workflow needs it. Then consider `guard_mode=deny`.

## Compare
Fresh `/context` and `/usage` against the baseline (rules/measure.md X3). Revert a change that does not help.

## Roll back
- One change: restore the file from `.claude/token-optimisation/backups/<time>/`.
- Everything the installer did: `sh install.sh --uninstall <project>` removes exactly what it recorded (block, our hooks and deny rules, the vendored skills, links, conf) and leaves the project as it was. Test it on a copy first.
- Hand edits from the conflict table are not recorded: revert them from git or the backups.
- The Claude Code mods are global: `claude plugin uninstall <name>@nextbrain-mods` for each.

## JSON trap
After any hand edit of a settings file run `python3 -m json.tool <file>`. One stray comma invalidates the file and silently drops every deny rule and hook.
