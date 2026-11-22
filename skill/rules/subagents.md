# Subagents and parallel calls

## A1 Broad search goes to an Explore subagent
When the owner of a symbol or topic is unknown across many files, delegate one search and keep only its conclusion. File dumps stay out of the main chat.

## A2 Parallelise independent calls
Send independent reads and commands in one message. Wait only for results the next call depends on.

## A3 Cheap model for read-only helpers
Searches, extraction and summaries can use the economy model role. Edits and judgement stay with the executor.

## A4 Do not delegate small lookups
A lookup of 1-3 calls is done inline. A subagent costs a full brief plus its report.

## A5 Pick the subagent model by tier
Set the model per task (roles from `config/defaults.conf`), never the main chat's (L3).
- fast (economy): read or summarise a file, run one command, rename a symbol.
- balanced (executor): a well-specified change across a few files, tests, a clearly described bug.
- deep (`role_deep`, Opus-class, never the planner or Fable, see L6): design, unknown failures, security, migrations, concurrency. Risky work is always deep.
Deep still stays small: effort high or lower unless the owner asks, a bounded brief, a report of about 250 words, stop when the question is answered.
Move down only when sure (heuristic: confidence 0.6 or more); when unsure keep the model. The `model-router` mod does this in Claude Code (`MODS.md`).

## A6 Research stays out of the main chat
Web research goes to a subagent or the `research-router` mod. The main chat gets a brief of about 200 words with numbered sources, not pages. Quick: up to 2 searches, up to 4 pages. Deep: 2-4 subagents on separate parts, each reports about 250 words.
