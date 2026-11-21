#!/bin/sh
# block.sh <file> insert|remove  : maintain the marker block from block.md
set -eu
f=$1; op=$2; H=$(cd "$(dirname "$0")" && pwd)
B='<!-- TOKEN-OPTIMISATION:BEGIN -->'; E='<!-- TOKEN-OPTIMISATION:END -->'
strip() { awk -v b="$B" -v e="$E" 'index($0,b){s=1;next} index($0,e){s=0;next} !s' "$f"; }
case "$op" in
  remove) [ -f "$f" ] && { t=$(mktemp); strip > "$t"; cat "$t" > "$f"; rm -f "$t"; } || true ;;
  insert) [ -f "$f" ] || : > "$f"
          t=$(mktemp); strip > "$t"
          { cat "$t"; printf '\n%s\n## Token optimisation\n' "$B"; cat "$H/block.md"; printf '%s\n' "$E"; } > "$f"; rm -f "$t" ;;
esac
