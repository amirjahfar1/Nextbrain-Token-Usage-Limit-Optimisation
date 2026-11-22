# Core rules (always on)

## K1 Entry files stay tiny
This system's own entry files stay short routing indexes (about 40 lines max); details live in linked files opened only when their trigger fires. The owner's AGENTS.md, CLAUDE.md and skills are never shortened, split, merged, renamed or moved without a yes.

## K2 One owner per rule
Each rule lives in exactly one file. Merge instead of duplicating; if two rules conflict, propose the resolution in place. Delete nothing of the owner's without a yes.

## K3 No big files
Every doc, rule and script of THIS system stays small (limits in `config/defaults.conf`). One that outgrows its limit is split in the same change: parent index plus small children (`bigfiles.md`). Owner files over a limit are reported only; they are never split without a yes.

## K4 Facts, not invented numbers
Never invent token counts, percentages or savings. Use real readings (`/context`, `/usage`, transcript data) and label thresholds as heuristics.

## K5 Safe before clever
An optimisation must not break existing behaviour. Verify, keep a backup, and ask before removing any existing rule, hook or connector.

## K6 Feed universal lessons back
When you optimise tokens or usage in any project, ask: would this help an unrelated project? If yes, also update the shared optimisation repo (private "Nextbrain-Token-Usage-Limit-Optimisation"; ask for its path if unknown) with the generic version. If it only fits this project, keep it local.
- Universal means: no project names, paths, owner details, account or connector ids, secrets. Describe by role and pattern.
- How: one registry row plus a `## ID` heading in the right rule file (or a script fix), `sh scripts/check-repo.sh`, bump `VERSION` and `CHANGELOG.md`, commit and push. Propose the generic change to the owner and push only after a yes; anything project-specific is never pushed.
- Then refresh projects with `install.sh --update <project>`. If unsure whether a lesson is universal, ask the owner.
