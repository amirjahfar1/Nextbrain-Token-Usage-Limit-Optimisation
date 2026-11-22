#!/bin/sh
# mods.sh <repo>: install or update the Claude Code mods in <repo>/mods for this user (scope user).
# Idempotent. Reads the mod list from mods/.claude-plugin/marketplace.json, so a new mod needs no change here.
# Never fails the caller: a missing CLI or python3 only prints what to do by hand (MODS.md).
R=$1; M=$R/mods; MK=nextbrain-mods
say() { echo "mods: $*"; }
[ -f "$M/.claude-plugin/marketplace.json" ] || { say "no mods folder in $R"; exit 0; }
C=$(command -v claude 2>/dev/null || true)
[ -n "$C" ] || C=$(ls -td "$HOME/Library/Application Support/Claude/claude-code"/*/*/claude.app/Contents/MacOS/claude 2>/dev/null | head -1)
{ [ -n "$C" ] && [ -x "$C" ]; } || { say "Claude Code CLI not found: install the mods by hand (MODS.md); ignore this for Codex"; exit 0; }
command -v python3 >/dev/null 2>&1 || { say "python3 not found: install it, then run this again (mods read the marketplace with it)"; exit 0; }
pairs=$(python3 -c 'import json,sys; print(" ".join(p["name"]+"="+p["version"] for p in json.load(open(sys.argv[1]))["plugins"]))' "$M/.claude-plugin/marketplace.json") \
  || { say "cannot read mods/.claude-plugin/marketplace.json"; exit 0; }
list=$("$C" plugin marketplace list 2>/dev/null || true)
if printf '%s\n' "$list" | grep -qF "Folder ($M)"; then
  "$C" plugin marketplace update "$MK" >/dev/null 2>&1 || say "marketplace update failed (continuing)"
else
  # not added yet, or added from another folder: point it at this one
  printf '%s\n' "$list" | grep -q "$MK" && "$C" plugin marketplace remove "$MK" >/dev/null 2>&1
  "$C" plugin marketplace add "$M" >/dev/null 2>&1 || { say "could not add the marketplace from $M"; exit 0; }
  say "marketplace $MK added from $M"
fi
# installed version of a mod ("" when not installed). `plugin list` shows the marketplace's version, not the
# installed copy's, so read the install record.
ver_of() {
  python3 -c 'import json,os,sys
f=os.path.join(os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude"),"plugins","installed_plugins.json")
try: print((json.load(open(f))["plugins"].get(sys.argv[1]) or [{}])[0].get("version",""))
except Exception: print("")' "$1@$MK"
}
ok=0; total=0
for pair in $pairs; do
  n=${pair%%=*}; want=${pair#*=}; total=$((total + 1)); cur=$(ver_of "$n")
  if [ -z "$cur" ]; then
    "$C" plugin install "$n@$MK" >/dev/null 2>&1 || say "install failed: $n (try: claude plugin install $n@$MK)"
    say "$n: not installed, installing v$want"
  elif [ "$cur" = "$want" ]; then say "$n: v$cur is current"
  else
    "$C" plugin update "$n@$MK" >/dev/null 2>&1 || say "update failed: $n (try: claude plugin update $n@$MK)"
    say "$n: v$cur is old, updating to v$want"
  fi
  now=$(ver_of "$n")
  if [ "$now" = "$want" ]; then ok=$((ok + 1)); elif [ -n "$now" ]; then say "$n: still v$now after the update (restart Claude Code to apply)"; ok=$((ok + 1)); fi
done
say "$ok of $total mods installed. A chat that is already open needs /reload-plugins or a new chat."
[ "$ok" = "$total" ] || say "not all installed: run 'claude plugin validate $M' and read the error"
exit 0
