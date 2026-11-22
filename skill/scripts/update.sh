#!/bin/sh
# Update this project's token-optimisation from its source repo. Usage: sh update.sh [project-dir]
# Pulls the source (fast-forward only) into a shared cache, shows what changed, then runs install.sh --auto.
# Only the owner's own repository is trusted: a different URL in a project's SOURCE file is ignored, because that
# file is committed with the project and could be changed by anyone who can open a pull request.
set -eu
D=$(cd "$(dirname "$0")/.." && pwd)
proj=${1:-$(cd "$D/../../.." && pwd)}
OWN=https://github.com/amirjahfar1/Nextbrain-Token-Usage-Limit-Optimisation.git
URL=${NEXTBRAIN_TOKEN_SYSTEM_URL:-$(head -1 "$D/SOURCE" 2>/dev/null || true)}
case "$URL" in
  https://github.com/amirjahfar1/Nextbrain-Token-Usage-Limit-Optimisation|https://github.com/amirjahfar1/Nextbrain-Token-Usage-Limit-Optimisation.git|git@github.com:amirjahfar1/Nextbrain-Token-Usage-Limit-Optimisation.git) ;;
  *) if [ -n "${NEXTBRAIN_TOKEN_SYSTEM_URL:-}" ]; then echo "update: using NEXTBRAIN_TOKEN_SYSTEM_URL=$URL (set by you)" >&2
     else [ -z "$URL" ] || echo "update: ignoring the source $URL (not the owner's repository)" >&2; URL=$OWN; fi ;;
esac
CACHE=${NEXTBRAIN_TOKEN_SYSTEM_DIR:-$HOME/.claude/nextbrain-token-system}
if [ -d "$CACHE/.git" ]; then
  old=$(git -C "$CACHE" rev-parse HEAD 2>/dev/null || true)
  if git -C "$CACHE" pull --ff-only -q; then
    new=$(git -C "$CACHE" rev-parse HEAD 2>/dev/null || true)
    if [ -n "$old" ] && [ "$old" != "$new" ]; then echo "update: new commits pulled:"; git -C "$CACHE" log --oneline "$old..$new" | head -20; fi
  else echo "update: could not pull (offline, no access or not a fast-forward); using the cached copy v$(cat "$CACHE/VERSION")" >&2; fi
else
  mkdir -p "$(dirname "$CACHE")"
  git clone -q "$URL" "$CACHE" || { echo "update: clone failed for $URL. Check the GitHub login on this Mac." >&2; exit 1; }
fi
exec sh "$CACHE/install.sh" --auto "$proj"
