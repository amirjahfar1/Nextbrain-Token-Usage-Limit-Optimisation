#!/bin/sh
# Install the token/usage optimisation system into a project.
# Usage: sh install.sh [--auto|--dry-run|--check|--update|--uninstall|--scan|--mods] [--hooks=all|guard|none]
#                      [--no-mods] [--force] [--allow-subdir] [project-dir]
# --auto decides for the project: update, install (brand-new project) or dry run (project with its own rules or
#   settings: nothing is written), then installs or updates the Claude Code mods (skip with --no-mods).
# --mods installs or updates only the Claude Code mods (once per Mac, no project needed).
# Every write is preceded by checks, so a refusal leaves the project untouched. Uninstall removes only what the
# installer recorded (installed.json). The hooks choice is kept in .agents/token-optimisation.conf (hooks=).
set -eu
R=$(cd "$(dirname "$0")" && pwd -P)
mode=install; proj=.; hooks=; force=0; subdir=0
for a in "$@"; do case "$a" in
  --hooks=*) hooks=${a#--hooks=} ;; --auto) mode=auto ;; --mods) mode=mods ;; --dry-run) mode=dry ;; --check) mode=check ;;
  --update) mode=update ;; --uninstall) mode=remove ;; --scan) mode=scan ;; --force) force=1 ;; --allow-subdir) subdir=1 ;;
  --no-mods) NEXTBRAIN_NO_MODS=1; export NEXTBRAIN_NO_MODS ;;
  -*) echo "unknown option $a" >&2; exit 2 ;; *) proj=$a ;; esac; done
[ "$mode" != mods ] || exec sh "$R/installer/mods.sh" "$R"
case "$hooks" in ""|all|guard|none) ;; *) echo "bad --hooks (use all, guard or none). Nothing was written." >&2; exit 2 ;; esac
command -v python3 >/dev/null 2>&1 || { echo "python3 is required (standard library only). Nothing was written." >&2; exit 2; }
[ -d "$proj" ] || { echo "no such folder: $proj" >&2; exit 2; }
proj=$(cd "$proj" && pwd -P)
[ "$proj" != "$R" ] || { echo "Run against a project, not the repo itself." >&2; exit 2; }
home=$(cd "$HOME" 2>/dev/null && pwd -P || echo "$HOME")
case "$proj" in "$home"|/) echo "Refusing $proj: a home or root folder is not a project. Nothing was written." >&2; exit 2 ;; esac
case "$R/" in "$proj"/*) echo "The repo lives inside $proj: run it against a project that does not contain the repo." >&2; exit 2 ;; esac
SK=$proj/.agents/skills/token-optimisation
if [ "$mode" != scan ] && [ "$subdir" = 0 ]; then
  top=$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$top" ] && [ "$(cd "$top" && pwd -P)" != "$proj" ]; then
    echo "$proj is inside the git project $top. Run it there (or pass --allow-subdir to install into this folder). Nothing was written." >&2; exit 2
  fi
fi
cf() { grep "^$1=" "$proj/.agents/token-optimisation.conf" 2>/dev/null | tail -1 | cut -d= -f2; }
[ -n "$hooks" ] || hooks=$(cf hooks || true)
case "${hooks:-all}" in all|"") ev= ;; guard) ev=--events=PreToolUse ;; none) ev=--events=none ;; *) echo "bad hooks= in the conf" >&2; exit 2 ;; esac
H=${hooks:-all}
newer() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" = "$1" ] && [ "$1" != "$2" ]; }
export NEXTBRAIN_BACKUP="$proj/.claude/token-optimisation/backups/$(date +%Y%m%d-%H%M%S)-$$"
case "$mode" in
  scan) cd "$proj"; python3 -B "$R/skill/scripts/bigfile.py" scan ;;
  auto) sh "$R/installer/auto.sh" "$R" "$proj" ;;
  dry) echo "DRY RUN for $proj (nothing is written)"
       python3 -B "$R/installer/files.py" "$R" "$proj" dry --hooks="$H"
       python3 -B "$R/installer/block.py" "$proj" insert --dry-run
       python3 -B "$R/installer/settings_merge.py" "$proj" merge --dry-run $ev | sed 's/^/  would: /' ;;
  install|update)
       have=$(cat "$SK/VERSION" 2>/dev/null || true)
       if [ -n "$have" ] && [ "$force" = 0 ] && newer "$have" "$(cat "$R/VERSION")"; then
         echo "project has v$have, this copy is v$(cat "$R/VERSION"): not downgrading (pass --force to override)"; exit 0; fi
       # checks first: any refusal here leaves the project untouched
       python3 -B "$R/installer/files.py" "$R" "$proj" preflight
       python3 -B "$R/installer/block.py" "$proj" insert --dry-run >/dev/null
       python3 -B "$R/installer/settings_merge.py" "$proj" merge --dry-run $ev >/dev/null
       python3 -B "$R/installer/files.py" "$R" "$proj" "$mode" --hooks="$H"
       python3 -B "$R/installer/block.py" "$proj" insert
       python3 -B "$R/installer/settings_merge.py" "$proj" merge $ev
       [ ! -d "$NEXTBRAIN_BACKUP" ] || echo "backup: $NEXTBRAIN_BACKUP"
       echo "installed v$(cat "$R/VERSION"). Next: sh '$0' --check '$proj'" ;;
  remove) python3 -B "$R/installer/settings_merge.py" "$proj" remove
       python3 -B "$R/installer/block.py" "$proj" remove
       python3 -B "$R/installer/files.py" "$R" "$proj" remove
       [ ! -d "$NEXTBRAIN_BACKUP" ] || echo "backup of changed files: $NEXTBRAIN_BACKUP"
       echo "removed what the installer added (backups kept in .claude/token-optimisation/backups)" ;;
  check) bad=0
       python3 -B "$R/installer/files.py" "$R" "$proj" check || bad=1
       f=$(python3 -B "$R/installer/block.py" "$proj" where 2>/dev/null || true)
       grep -q 'TOKEN-OPTIMISATION:BEGIN' "$f" 2>/dev/null || { echo "block: missing"; bad=1; }
       grep -q 'token-optimisation/hooks/' "$proj/.claude/settings.json" 2>/dev/null || echo "hooks: none installed (ok if --hooks=none)"
       sh "$SK/scripts/gen-tips.sh" --check || bad=1
       enf=$(cf enforce_size || true)
       (cd "$proj" && sh "$SK/scripts/check-size.sh" "$SK") || { [ "${enf:-1}" = 0 ] && echo "size: advisory only (enforce_size=0)" || bad=1; }
       echo '{}' | python3 -B "$SK/hooks/guard_read.py" || { echo "guard smoke test failed"; bad=1; }
       [ "$bad" = 0 ] && echo "check: all ok"; exit "$bad" ;;
esac
