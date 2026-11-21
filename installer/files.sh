#!/bin/sh
# files.sh <repo> <project> install|update|remove|check [dry]
set -eu
repo=$1; proj=$2; op=$3; dry=${4:-}
sk=$proj/.agents/skills; man=$sk/token-optimisation/.manifest
hash() { shasum -a 256 "$1" | cut -d' ' -f1; }
run() { if [ -n "$dry" ]; then echo "  would: $*"; else "$@"; fi; }
link() {
  if [ -n "$dry" ]; then echo "  would link .claude/skills/$1"; return; fi
  mkdir -p "$proj/.claude/skills"
  [ -e "$proj/.claude/skills/$1" ] || ln -s "../../.agents/skills/$1" "$proj/.claude/skills/$1" 2>/dev/null || cp -R "$sk/$1" "$proj/.claude/skills/$1"
}
sync() {
  src=$1; name=$2
  if [ -d "$sk/$name" ] && [ ! -f "$sk/$name/.managed" ]; then echo "  kept existing unmanaged skill: $name (merge it in ADOPTION)"; return; fi
  find "$src" -type f | while read -r f; do
    rel=${f#"$src"/}; t=$sk/$name/$rel
    if [ -f "$t" ] && [ "$op" = update ] && [ -f "$man" ]; then
      old=$(grep -F "  $name/$rel" "$man" | cut -d' ' -f1 || true)
      if [ -n "$old" ] && [ "$old" != "$(hash "$t")" ]; then echo "  kept locally edited: $name/$rel"; continue; fi
    fi
    run mkdir -p "$(dirname "$t")"; run cp "$f" "$t"
  done
  [ -n "$dry" ] || touch "$sk/$name/.managed"
}
case "$op" in
  install|update)
    sync "$repo/skill" token-optimisation; sync "$repo/skill-tips" tips
    if [ -z "$dry" ]; then
      cp "$repo/VERSION" "$sk/token-optimisation/VERSION"
      (cd "$sk" && for n in token-optimisation tips; do [ -f "$n/.managed" ] && find "$n" -type f -not -name .manifest -not -name .managed | while read -r f; do echo "$(hash "$f")  $f"; done; done) > "$man"
      [ -f "$proj/.agents/token-optimisation.conf" ] || printf '# project overrides for token-optimisation (defaults: skill/config/defaults.conf)\nguard_mode=log\nranged=\n' > "$proj/.agents/token-optimisation.conf"
    fi
    link token-optimisation; link tips ;;
  remove)
    for n in token-optimisation tips; do
      if [ -f "$sk/$n/.managed" ]; then rm -rf "${sk:?}/${n:?}"; rm -f "$proj/.claude/skills/$n"; fi
    done ;;
  check)
    [ -f "$man" ] || { echo "files: not installed"; exit 1; }
    bad=0
    while read -r h f; do
      [ -f "$sk/$f" ] || { echo "files: missing $f"; bad=1; continue; }
      [ "$h" = "$(hash "$sk/$f")" ] || echo "files: locally edited $f"
    done < "$man"
    [ "$(cat "$sk/token-optimisation/VERSION")" = "$(cat "$repo/VERSION")" ] || echo "files: update available ($(cat "$repo/VERSION"))"
    exit "$bad" ;;
esac
