# Nextbrain Token | Usage Limit Optimisation

Private, portable system that lowers token use and protects usage limits for Claude Code and Codex.

- Small always-loaded block (5 lines) plus on-demand rule files; no file is big.
- Guards for big and generated files, index and shard tools for managing them.
- Expensive-session review: every session is recorded; a flagged one prompts a cost report and suggested fixes, applied only with owner approval.
- `/tips` or `$tips` prints every optimisation, generated from one registry.
- Safe adoption path for existing projects (`ADOPTION.md`).

## Use it
Tell the agent in any project: "Follow `<path to this repo>/START-HERE.md`." Or:

```sh
sh install.sh --dry-run /path/to/project
sh install.sh /path/to/project
sh install.sh --check /path/to/project
```

Also: `--update`, `--uninstall`, `--scan`. Needs `sh`, `python3` (stdlib only). Works offline after install.

## Maintain
`sh scripts/check-repo.sh` (size limits, tips sync, links, secret patterns). Add a tip: one registry row plus a `## ID` heading in its rule file, then `sh skill/scripts/gen-tips.sh`.

Private repo: contains no secrets or personal data. Model names are owner-configurable in `skill/config/defaults.conf`.
