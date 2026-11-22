# Token Meter

A side pane for Claude Code, with a full report behind one button.

- **Token Meter card:** context used (bar, tokens of the window), five hour and seven day limits, cost estimate.
- **Today card:** sessions, cache hit, input, output, cost, and the tokens the mods kept out of context. Buttons: Full report, Refresh.
- **Top Tools card:** the tools this chat called most.
- **Full report** (second pane, `/token-report`): pick Today, 7 days, 30 days or All time. It shows sessions, requests, input (fresh and cached), output, cache hit, cost estimate, **whether the system is paying off** (see below), measured savings (tokens and %), by day, by model, by project and top tools. "Open report file" opens the same report as markdown in `~/.claude/mods-logs/token-meter/`.

Commands: `/token-meter` (the pane), `/token-report` (the report).

## Is the system paying off?
After a few days of use the report compares, per request, the sessions of a project before the token system was installed there with the sessions after it (cost, fresh input, tool output size, average peak context, cache hit, compactions), and turns the difference into an indicative saving in dollars and tokens. It needs 20 requests on each side before it shows a number ("Collecting data" until then). The same split is made for the mods (before and after their install date, all projects), and the guard's flagged big reads are counted. Tasks differ between sessions, so it is an indicator that firms up with more sessions, not proof.

## How it counts
- `bin/report.py` (python3, stdlib) reads the chat transcripts once per request. Cost is a list-price estimate, not a bill.
- Savings come from the mods ledger `~/.claude/mods-logs/savings.jsonl` (what each mod cut, before and after). Saved % = kept out / (kept out + fresh input that did enter). Dollar savings come from model routing only.
- Savings from the rules (reading discipline, guards) are not measured, so the real saving is higher.
- Run the report by hand: `python3 bin/report.py 30d` (markdown) or `--json`.

Needs python3. The pane draws in the desktop app; the terminal shows text.
