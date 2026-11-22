#!/bin/sh
# Fail when a file exceeds its size limit. Usage: check-size.sh [path...]  (default: .)
D=$(cd "$(dirname "$0")/.." && pwd)
cfg() { v=$(cat "$D/config/defaults.conf" ./.agents/token-optimisation.conf 2>/dev/null | grep "^$1=" | tail -1 | cut -d= -f2); echo "${v:-$2}"; }
MDL=$(cfg max_md_lines 100); MDB=$(cfg max_md_bytes 6144); CL=$(cfg max_code_lines 150)
CB=$(cfg max_code_bytes 8192); DL=$(cfg max_data_lines 120); EL=$(cfg max_entry_lines 40)
[ $# -gt 0 ] || set -- .
bad=0
find "$@" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/dist/*' \
  -not -path '*/.claude/token-optimisation/*' -not -path '*/token-saving-mods/*' -not -path '*/mods/plugins/*' 2>/dev/null | while read -r f; do
  b=$(basename "$f"); lines=$(wc -l < "$f" | tr -d ' '); bytes=$(wc -c < "$f" | tr -d ' ')
  case "$b" in
    pnpm-lock.yaml|package-lock.json|yarn.lock) echo "BIG(never-open): $f ($bytes bytes) -> class never"; continue ;;
    SKILL.md|START-HERE.md|AGENTS.md|CLAUDE.md) ml=$EL; mb=999999 ;;
    *.md) ml=$MDL; mb=$MDB ;;
    *.sh|*.py) ml=$CL; mb=$CB ;;
    *.tsv|*.json|*.conf|*.yml|*.yaml|*.toml) ml=$DL; mb=999999 ;;
    *) continue ;;
  esac
  if [ "$lines" -gt "$ml" ] || [ "$bytes" -gt "$mb" ]; then echo "BIG: $f ($lines lines, $bytes bytes; limit $ml lines)"; fi
done | tee /tmp/.tokopt-size.$$ >&2
n=$(grep -c '^BIG' /tmp/.tokopt-size.$$ 2>/dev/null); rm -f /tmp/.tokopt-size.$$
[ "${n:-0}" = 0 ] && { echo "size: ok"; exit 0; }
echo "size: $n file(s) over limit. Split into parent index + children (rules/bigfiles.md)." >&2; exit 1
