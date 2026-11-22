# Nextbrain Token | Usage Limit Optimisation

Private, portable system that lowers token use and protects usage limits for Claude Code and Codex.

- Small always-loaded block (5 lines) plus on-demand rule files; no file is big.
- Guards for big and generated files, index and shard tools for managing them.
- Expensive-session review: every session is recorded; a flagged one prompts a cost report and suggested fixes, applied only with owner approval.
- `/tips` or `$tips` prints every optimisation, generated from one registry.
- Optional Claude Code mods, installed once for all projects: `MODS.md`.
- Safe adoption path for existing projects (`ADOPTION.md`). Reading map: `MAP.md`. Commands: `/tips`, `/token-audit` (usage report, see `skill/guides/token-audit.md`), `/handoff`.

## Use it
Tell the agent in any project: "Follow `<path to this repo>/START-HERE.md`", or just give it the GitHub URL, or say "token system updated": it keeps one copy in `~/.claude/nextbrain-token-system` and runs `sh install.sh --auto <project>`. Manual:

```sh
sh install.sh --dry-run /path/to/project
sh install.sh /path/to/project
sh install.sh --check /path/to/project
```

Also: `--auto` (decides update, install or dry run for you), `--update`, `--uninstall`, `--scan`. Needs `sh`, `python3` (stdlib only). Works offline after install.

## Maintain
`sh scripts/check-repo.sh` (size limits, tips sync, links, secret patterns). Add a tip: one registry row plus a `## ID` heading in its rule file, then `sh skill/scripts/gen-tips.sh`.

Private repo: contains no secrets or personal data. Model names are owner-configurable in `skill/config/defaults.conf`.
