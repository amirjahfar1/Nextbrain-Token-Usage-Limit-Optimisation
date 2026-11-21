# Core rules (always on)

## K1 Entry files stay tiny
AGENTS.md and CLAUDE.md are short routing indexes (about 40 lines max). Details live in linked files that are opened only when their trigger fires.

## K2 One owner per rule
Each rule lives in exactly one file. Merge instead of duplicating; if two rules conflict, resolve in place and delete the loser.

## K3 No big files
Every doc, rule and script stays small (limits in `config/defaults.conf`). A file that outgrows its limit is split in the same change: parent index plus small children. See `bigfiles.md`.

## K4 Facts, not invented numbers
Never invent token counts, percentages or savings. Use real readings (`/context`, `/usage`, transcript data) and label thresholds as heuristics.

## K5 Safe before clever
An optimisation must not break existing behaviour. Verify, keep a backup, and ask before removing any existing rule, hook or connector.
