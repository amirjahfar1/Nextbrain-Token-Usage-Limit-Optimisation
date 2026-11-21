#!/bin/sh
# Print tips: --all | <area letter> | <area name> | <id>
D=$(cd "$(dirname "$0")/.." && pwd)
awk -F'\t' -v a="${1:---all}" '
/^#/ || NF < 6 { next }
{ u = toupper(a)
  if (a == "--all" || toupper(substr($1,1,1)) == u || $1 == u || $2 == a) {
    if ($2 != last) { printf "\n[%s]\n", $2; last = $2 }
    printf "%s  %s  -> %s\n", $1, $3, $5 } }' "$D/tips/registry.tsv"
