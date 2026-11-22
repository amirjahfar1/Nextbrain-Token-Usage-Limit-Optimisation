#!/bin/sh
# auto.sh <repo> <project>: decide what this project needs and do only the safe part. Prints a short report.
#   installed, older   -> update, then show the CHANGELOG entries since its version, then check
#   installed, current -> check only
#   brand new project  -> install, then check
#   has its own rules, settings or skills -> dry run ONLY, nothing written, no mods; the owner approves a plan first
set -eu
R=$1; P=$2; SK=$P/.agents/skills/token-optimisation; new=$(cat "$R/VERSION")
say() { echo "auto: $*"; }
say "FIRST, before reading the project, planning or optimising anything: ask the owner 'Plan with Fable (strongest, costs more) or with the current model?' and wait for the answer (skill/rules/models.md L6). Never pick Fable yourself."
has_own() {
  for f in AGENTS.md CLAUDE.md CLAUDE.local.md GEMINI.md .cursorrules .windsurfrules .claude/CLAUDE.md .claude/settings.json \
           .claude/settings.local.json .mcp.json .github/copilot-instructions.md; do [ -s "$P/$f" ] && return 0; done
  for d in .agents .claude/skills .claude/commands .claude/agents .claude/rules .claude/hooks .codex .cursor .github/instructions .windsurf; do
    [ -n "$(ls -A "$P/$d" 2>/dev/null)" ] && return 0; done
  [ -n "$(find "$P" -maxdepth 4 \( -name CLAUDE.md -o -name AGENTS.md \) -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1)" ] && return 0
  return 1
}
next="summarise the changes in 3 lines, then check the project's own AGENTS.md/CLAUDE.md for rules that clash with the new ones and propose edits (never change owner rules without a yes)."
mods=1
if [ -f "$SK/.manifest" ]; then
  old=$(cat "$SK/VERSION" 2>/dev/null || echo unknown)
  top=$(printf '%s\n%s\n' "$old" "$new" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
  if [ "$old" = "$new" ]; then say "installed v$old, already current"
  elif [ "$top" = "$old" ]; then say "project v$old is newer than the source v$new: not downgrading (did the pull fail? check the GitHub login)"
  else
    say "installed v$old, updating to v$new"
    sh "$R/install.sh" --update "$P"
    say "changes since v$old (CHANGELOG):"
    awk -v o="$old" 'f { print } index($0, "## " o " ") { f = 1 }' "$R/CHANGELOG.md"
  fi
  sh "$R/install.sh" --check "$P" || say "CHECK FAILED: show the owner the lines above"
elif has_own; then
  mods=0
  say "this project has its own rules, settings or skills: NOT installing, no mods touched. Dry run:"
  sh "$R/install.sh" --dry-run "$P"
  next="follow $R/ADOPTION.md: ask the owner the questions in its Phase 0, inventory cheaply, plan, wait for approval, then apply. Nothing is written before that."
else
  say "new project: installing v$new"
  sh "$R/install.sh" "$P"
  sh "$R/install.sh" --check "$P" || say "CHECK FAILED: show the owner the lines above"
fi
say "big or generated files in this project (scan):"
(cd "$P" && python3 -B "$R/skill/scripts/bigfile.py" scan 2>&1 | head -12) || true
if [ "$mods" = 0 ]; then say "mods: not touched (own-rules project). After the owner approves the plan: sh $R/install.sh --mods"
elif [ -n "${NEXTBRAIN_NO_MODS:-}" ]; then say "mods: skipped (--no-mods)"
else sh "$R/installer/mods.sh" "$R"; fi
say "done. Next: $next"
