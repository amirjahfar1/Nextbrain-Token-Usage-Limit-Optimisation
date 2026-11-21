# Subagents and parallel calls

## A1 Broad search goes to an Explore subagent
When the owner of a symbol or topic is unknown across many files, delegate one search and keep only its conclusion. File dumps stay out of the main chat.

## A2 Parallelise independent calls
Send independent reads and commands in one message. Wait only for results the next call depends on.

## A3 Cheap model for read-only helpers
Searches, extraction and summaries can use the economy model role. Edits and judgement stay with the executor.

## A4 Do not delegate small lookups
A lookup of 1-3 calls is done inline. A subagent costs a full brief plus its report.
