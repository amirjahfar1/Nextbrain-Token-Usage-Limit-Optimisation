# Reading map: which file, when

Rule: open the parent only, then ONE child. Never a whole folder.

| Level | File | Open when |
|---|---|---|
| Always loaded | 5-line block in AGENTS.md | automatic |
| Parent | `skill/SKILL.md` (40 lines) | any token/usage question; routes to one child |
| Parent | `START-HERE.md` | this repo is handed to a project |
| Parent | `ADOPTION.md` | project already has its own rules/hooks/settings |
| Child | `adoption/01-inventory.md`, `02-plan.md`, `03-apply-verify-rollback.md` | adoption phase 1-2 / 3 / 4 |
| Child | `rules/reading.md` | before reading code or running commands |
| Child | `rules/requests.md`, `output.md` | receiving a request / writing a reply |
| Child | `rules/bigfiles.md` | a lockfile, generated or oversized file |
| Child | `rules/mcp.md` | connector or plugin overhead |
| Child | `rules/models.md` | choosing a model or effort |
| Child | `rules/session.md`, `measure.md` | context growing, checkpoint, baseline |
| Child | `rules/session-review.md` | a session was flagged expensive, or `/token-audit` |
| Child | `rules/subagents.md`, `commands.md`, `codex.md`, `core.md` | delegating / client commands / Codex / always-on rules |
| Registry | `skill/tips/registry.tsv` | never opened by hand; `/tips` prints it |

Commands: `/tips` (all tips), `/token-audit` (read-only audit and running report; guide: `skill/guides/token-audit.md`), `/handoff` (checkpoint before clearing). Big shards: `rg -l '<id>' <shard dir>`, then open that one shard.
