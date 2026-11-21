#!/bin/sh
# Print tips grouped by area: --all | <area letter> | <area name> | <id>
D=$(cd "$(dirname "$0")/.." && pwd)
awk -F'\t' -v a="${1:---all}" '
/^#/ || NF < 6 { next }
{ u = toupper(a)
  if (a == "--all" || toupper(substr($1,1,1)) == u || $1 == u || $2 == a) {
    if (!($2 in seen)) { seen[$2] = 1; order[++k] = $2 }
    body[$2] = body[$2] sprintf("%s  %s  -> %s\n", $1, $3, $5) } }
END { for (i = 1; i <= k; i++) printf "\n[%s]\n%s", order[i], body[order[i]] }' "$D/tips/registry.tsv"
