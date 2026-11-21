# Reading discipline

## R1 Locate before you read
Find the owner first: CODEMAP row, one bounded code-graph query, or `grep -n`. Never `find`/`grep -r` the whole tree or read files "to get a feel".

## R2 Read ranges, 2-5 files per task
Use `Read` with offset/limit around the symbol. If you need more than 5 files, you are in the wrong place: re-locate.

## R3 Cap command output
Pipe through `head -n` / `tail -n`. Send long logs to a file and `grep` it. Never print a whole log or test run.

## R4 Never re-read
Do not re-read a file already in context or one you just edited. The edit succeeded or errored; trust it.

## R5 Query, do not open, generated files
Lockfiles, build output, minified and generated files are never opened. Use the package manager or `grep -n -m 20`.

## R6 Printed source counts as read
If a tool (code-graph explore, diff, grep with context) already printed the code, do not open the file again.
