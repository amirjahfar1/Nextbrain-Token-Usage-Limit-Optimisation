#!/bin/sh
# mods.sh <repo>: install or update the Claude Code mods in <repo>/mods for this user (scope user).
# Idempotent. Reads the mod list from mods/.claude-plugin/marketplace.json, so a new mod needs no change here.
# A mod the owner disabled stays disabled. Never fails the caller: a missing CLI or python3 only prints what to do
# by hand (MODS.md). Called by --auto only for a brand-new or already installed project, never for one that has its
# own rules; `install.sh --mods` runs it on its own.
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
# the marketplace's current source folder, "" when not added (the CLI may wrap the path in quotes)
old=$(printf '%s\n' "$list" | python3 -c 'import re,sys
t=sys.stdin.read(); m=re.search(r"nextbrain-mods\s+Source: Folder \((.*?)\)\s*(?:\n|$)", t)
print(re.sub("[“”\"]", "", m.group(1)) if m else "")')
if [ "$old" = "$M" ]; then
  "$C" plugin marketplace update "$MK" >/dev/null 2>&1 || say "marketplace update failed (continuing)"
else
  # not added yet, or added from another folder: point it at this one; put the old one back if that fails
  if printf '%s\n' "$list" | grep -q "$MK"; then "$C" plugin marketplace remove "$MK" >/dev/null 2>&1; fi
  if ! "$C" plugin marketplace add "$M" >/dev/null 2>&1; then
    say "could not add the marketplace from $M"
    [ -z "$old" ] || "$C" plugin marketplace add "$old" >/dev/null 2>&1 || true
    exit 0
  fi
  say "marketplace $MK added from $M"
fi
# installed version of a mod ("" when not installed). `plugin list` shows the marketplace's version, not the
# installed copy's, so read the install record. disabled: succeeds when the owner turned the mod off.
ver_of() {
  python3 -c 'import json,os,sys
d=os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
try: print((json.load(open(os.path.join(d,"plugins","installed_plugins.json")))["plugins"].get(sys.argv[1]) or [{}])[0].get("version",""))
except Exception: print("")' "$1@$MK"
}
disabled() {
  python3 -c 'import json,os,sys
d=os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
try: sys.exit(0 if json.load(open(os.path.join(d,"settings.json"))).get("enabledPlugins",{}).get(sys.argv[1]) is False else 1)
except Exception: sys.exit(1)' "$1@$MK"
}
ok=0; total=0
for pair in $pairs; do
  n=${pair%%=*}; want=${pair#*=}; total=$((total + 1)); cur=$(ver_of "$n"); tried=0
  if [ -z "$cur" ]; then
    if "$C" plugin install "$n@$MK" >/dev/null 2>&1; then say "$n: installed v$want"; else say "install failed: $n (try: claude plugin install $n@$MK)"; fi
  elif disabled "$n"; then say "$n: v$cur is disabled by the owner, left alone"
  elif [ "$cur" = "$want" ]; then say "$n: v$cur is current"
  else
    tried=1
    if "$C" plugin update "$n@$MK" >/dev/null 2>&1; then say "$n: updated v$cur to v$want"; else say "update failed: $n v$cur (try: claude plugin update $n@$MK)"; fi
  fi
  now=$(ver_of "$n")
  if [ "$now" = "$want" ]; then ok=$((ok + 1)); elif [ -n "$now" ]; then [ "$tried" = 0 ] || say "$n: still v$now after the update (restart Claude Code to apply)"; ok=$((ok + 1)); fi
done
say "$ok of $total mods installed. A chat that is already open needs /reload-plugins or a new chat."
[ "$ok" = "$total" ] || say "not all installed: run 'claude plugin validate $M' and read the error"
exit 0
