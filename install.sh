#!/bin/sh
# Install the token/usage optimisation system into a project.
# Usage: sh install.sh [--auto|--dry-run|--check|--update|--uninstall|--scan] [--hooks=all|guard|none] [project-dir]
# --auto decides for the project: update, install (new project) or dry run (project with its own rules).
set -eu
R=$(cd "$(dirname "$0")" && pwd)
mode=install; proj=.; hooks=all
for a in "$@"; do case "$a" in
  --hooks=*) hooks=${a#--hooks=} ;; --auto) mode=auto ;; --dry-run) mode=dry ;; --check) mode=check ;; --update) mode=update ;; --uninstall) mode=remove ;; --scan) mode=scan ;;
  -*) echo "unknown option $a" >&2; exit 2 ;; *) proj=$a ;; esac; done
proj=$(cd "$proj" && pwd); SK=$proj/.agents/skills/token-optimisation
[ "$proj" != "$R" ] || { echo "Run against a project, not the repo itself." >&2; exit 2; }
entry() {
  if [ -f "$proj/AGENTS.md" ]; then echo "$proj/AGENTS.md"; elif [ -f "$proj/CLAUDE.md" ]; then echo "$proj/CLAUDE.md"; else echo "$proj/AGENTS.md"; fi; }
backup() {
  b=$proj/.claude/token-optimisation/backups/$(date +%Y%m%d-%H%M%S); mkdir -p "$b"
  for f in AGENTS.md CLAUDE.md; do [ -f "$proj/$f" ] && cp "$proj/$f" "$b/$f"; done; echo "backup: $b"; }
case "$mode" in
  auto) sh "$R/installer/auto.sh" "$R" "$proj" ;;
  scan) cd "$proj"; python3 "$R/skill/scripts/bigfile.py" scan ;;
  dry) echo "DRY RUN for $proj (nothing written)"; sh "$R/installer/files.sh" "$R" "$proj" install dry
       echo "  would add block to $(entry)"; python3 "$R/installer/settings_merge.py" "$proj" merge --dry-run | sed 's/^/  would: /' ;;
  install|update) backup
       sh "$R/installer/files.sh" "$R" "$proj" "$mode"
       sh "$R/installer/block.sh" "$(entry)" insert
       case "$hooks" in all) ev= ;; guard) ev=--events=PreToolUse ;; none) ev=--events=none ;; *) echo "bad --hooks" >&2; exit 2 ;; esac
       python3 "$R/installer/settings_merge.py" "$proj" merge $ev
       grep -q '^\.claude/token-optimisation' "$proj/.gitignore" 2>/dev/null || printf '\n# token-optimisation local state\n.claude/token-optimisation/\n' >> "$proj/.gitignore"
       echo "installed v$(cat "$R/VERSION"). Next: sh $0 --check $proj" ;;
  remove) backup; sh "$R/installer/block.sh" "$(entry)" remove
       python3 "$R/installer/settings_merge.py" "$proj" remove; sh "$R/installer/files.sh" "$R" "$proj" remove
       echo "removed (backups kept in .claude/token-optimisation/backups)" ;;
  check) bad=0
       sh "$R/installer/files.sh" "$R" "$proj" check || bad=1
       grep -q 'TOKEN-OPTIMISATION:BEGIN' "$(entry)" 2>/dev/null || { echo "block: missing"; bad=1; }
       grep -q 'token-optimisation/hooks/' "$proj/.claude/settings.json" 2>/dev/null || echo "hooks: none installed (ok if --hooks=none)"
       sh "$SK/scripts/gen-tips.sh" --check || bad=1
       enf=$(grep '^enforce_size=' "$proj/.agents/token-optimisation.conf" 2>/dev/null | cut -d= -f2)
       (cd "$proj" && sh "$SK/scripts/check-size.sh" "$SK") || { [ "${enf:-1}" = 0 ] && echo "size: advisory only (enforce_size=0)" || bad=1; }
       echo '{}' | python3 "$SK/hooks/guard_read.py" || { echo "guard smoke test failed"; bad=1; }
       [ "$bad" = 0 ] && echo "check: all ok"; exit "$bad" ;;
esac
