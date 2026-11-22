# Reading discipline

## R1 Locate before you read
Find the owner first: the area in `.claude/token-optimisation/ROUTES.md` (generated routing map, if present), then a CODEMAP row, one bounded code-graph query, or `grep -n` inside that area. Never `find`/`grep -r` the whole tree or read files "to get a feel".

## R2 Read what the task needs, in ranges
Use `Read` with offset/limit around the symbol. Read the few files the task really needs; for a large change list the affected files first, then read what each change needs. If you keep opening unrelated files, re-locate.

## R3 Cap command output
Pipe through `head -n` / `tail -n`. Send long logs to a file and `grep` it. Never print a whole log or test run.

## R4 Do not re-read an unchanged file
Do not re-read a file already in context or one you just edited: the edit succeeded or errored. Do re-read after a compaction, after a tool, formatter or hook changed it, or when exact text matters.

## R5 Query, do not open, generated files
Lockfiles, build output, minified and generated files are never opened. Use the package manager or `grep -n -m 20`.

## R6 Printed source counts as read
If a tool (code-graph explore, diff, grep with context) already printed the code, do not open the file again.
