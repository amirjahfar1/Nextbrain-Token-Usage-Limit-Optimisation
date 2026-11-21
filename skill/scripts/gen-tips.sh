#!/bin/sh
# Regenerate the tip-area block in SKILL.md. --check validates registry, headings and block.
set -eu
D=$(cd "$(dirname "$0")/.." && pwd)
REG=$D/tips/registry.tsv
T=$(mktemp)
trap 'rm -f "$T" "$T.n"' EXIT
awk -F'\t' '/^#/ || NF < 6 { next }
  !($2 in n) { o[++k] = $2; f[$2] = $5; sub(/#.*/, "", f[$2]) } { n[$2]++ }
  END { for (i = 1; i <= k; i++) printf "- %s (%d tips) -> %s\n", o[i], n[o[i]], f[o[i]] }' "$REG" > "$T"
render() {
  awk -v g="$T" 'BEGIN { while ((getline l < g) > 0) gen = gen l "\n" }
    /<!-- TIPS:BEGIN -->/ { print; printf "%s", gen; skip = 1; next }
    /<!-- TIPS:END -->/ { skip = 0 } !skip { print }' "$D/SKILL.md"
}
if [ "${1:-}" != "--check" ]; then render > "$T.n"; cat "$T.n" > "$D/SKILL.md"; echo "SKILL.md tip block updated"; exit 0; fi
bad=0
err() { echo "tips: $*" >&2; bad=1; }
[ "$(wc -l < "$REG")" -le 120 ] || err "registry over 120 lines (shard it by area)"
[ -z "$(awk -F'\t' '/^#/||NF<6{next} seen[$1]++{print 1}' "$REG")" ] || err "duplicate tip id"
[ -z "$(awk -F'\t' '/^#/||NF<6{next} length($3)>110{print 1}' "$REG")" ] || err "a tip is over 110 chars"
while IFS="$(printf '\t')" read -r id area tip trig fa enf; do
  case "$id" in '#'*|'') continue ;; esac
  file=${fa%%#*}
  [ -f "$D/$file" ] || { err "$id: missing file $file"; continue; }
  grep -q "^## $id " "$D/$file" || err "$id: no heading '## $id' in $file"
done < "$REG"
for f in "$D"/rules/*.md; do
  for id in $(grep -o '^## [A-Z][0-9]* ' "$f" | cut -c4- | tr -d ' '); do
    grep -q "^$id	" "$REG" || err "heading $id in $(basename "$f") has no registry row"
  done
done
render > "$T.n"; cmp -s "$T.n" "$D/SKILL.md" || err "SKILL.md tip block is stale: run gen-tips.sh"
[ "$bad" = 0 ] && echo "tips: ok ($(grep -vc '^#' "$REG") tips)"
exit "$bad"
