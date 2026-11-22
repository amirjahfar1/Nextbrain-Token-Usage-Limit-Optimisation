#!/bin/sh
# Repo self-check: size limits, tips sync, relative links, secret patterns, hook smoke test.
R=$(cd "$(dirname "$0")/.." && pwd); bad=0
sh "$R/skill/scripts/check-size.sh" "$R" || bad=1
sh "$R/skill/scripts/gen-tips.sh" --check || bad=1
find "$R" -name '*.md' -not -path '*/.git/*' -not -path '*/token-saving-mods/*' | while read -r f; do
  grep -o '](\([^)#h][^)#]*\)' "$f" | sed 's/](//' | while read -r l; do
    [ -e "$(dirname "$f")/$l" ] || echo "link: broken $l in ${f#"$R"/}"; done; done | tee /tmp/.tokopt-links.$$ >&2
[ -s /tmp/.tokopt-links.$$ ] && bad=1; rm -f /tmp/.tokopt-links.$$
if grep -rIE 'ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA |EC )?PRIVATE KEY|sk-[A-Za-z0-9]{30,}' "$R" --exclude-dir=.git --exclude-dir=token-saving-mods >/dev/null; then echo "secret pattern found" >&2; bad=1; fi
python3 -I - "$R" <<'PY' || bad=1
import json, sys
R = sys.argv[1]; bad = 0
m = json.load(open(R + "/mods/.claude-plugin/marketplace.json")); doc = open(R + "/MODS.md").read()
for p in m["plugins"]:
    try: v = json.load(open(R + "/mods/" + p["source"].lstrip("./") + "/.claude-plugin/plugin.json"))["version"]
    except Exception: print("mods: no plugin.json for", p["name"]); bad = 1; continue
    if v != p["version"]: print("mods: %s is %s in plugin.json but %s in marketplace.json" % (p["name"], v, p["version"])); bad = 1
    if "| %s |" % p["name"] not in doc or "/plugin install %s@" % p["name"] not in doc: print("mods: %s is not in the MODS.md table and install list" % p["name"]); bad = 1
sys.exit(bad)
PY
echo '{}' | python3 "$R/skill/hooks/guard_read.py" || bad=1
[ "$bad" = 0 ] && echo "repo check: all ok"; exit "$bad"
