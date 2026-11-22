#!/bin/sh
# Update this project's token-optimisation from its source repo. Usage: sh update.sh [project-dir]
# Pulls the source into a shared cache, then runs install.sh --auto on the project.
set -eu
D=$(cd "$(dirname "$0")/.." && pwd)
proj=${1:-$(cd "$D/../../.." && pwd)}
URL=${NEXTBRAIN_TOKEN_SYSTEM_URL:-$(head -1 "$D/SOURCE" 2>/dev/null || true)}
URL=${URL:-https://github.com/amirjahfar1/Nextbrain-Token-Usage-Limit-Optimisation.git}
CACHE=${NEXTBRAIN_TOKEN_SYSTEM_DIR:-$HOME/.claude/nextbrain-token-system}
if [ -d "$CACHE/.git" ]; then
  git -C "$CACHE" pull --ff-only -q || echo "update: could not pull (offline or no access); using the cached copy v$(cat "$CACHE/VERSION")" >&2
else
  mkdir -p "$(dirname "$CACHE")"
  git clone -q "$URL" "$CACHE" || { echo "update: clone failed for $URL. Check the GitHub login on this Mac." >&2; exit 1; }
fi
exec sh "$CACHE/install.sh" --auto "$proj"
