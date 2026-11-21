#!/usr/bin/env python3
"""Additive merge of settings.snippet.json into .claude/settings.json.
Usage: settings_merge.py <project> merge|remove [--dry-run] [--events=PreToolUse,...]. Never edits other keys. Aborts on invalid JSON."""
import json, os, shutil, sys, time

MARK = "token-optimisation/hooks/"
here = os.path.dirname(os.path.abspath(__file__))
proj, mode, dry = sys.argv[1], sys.argv[2], "--dry-run" in sys.argv
path = os.path.join(proj, ".claude", "settings.json")
snip = json.load(open(os.path.join(here, "settings.snippet.json")))
try:
    cur = json.load(open(path)) if os.path.exists(path) else {}
except ValueError:
    sys.exit("settings.json is invalid JSON; not touching it. Merge installer/settings.snippet.json by hand.")
if not isinstance(cur, dict):
    sys.exit("settings.json is not an object; not touching it.")
only = next((a.split("=",1)[1].split(",") for a in sys.argv if a.startswith("--events=")), None)
added = []
deny = cur.setdefault("permissions", {}).setdefault("deny", [])
hooks = cur.setdefault("hooks", {})
if mode == "merge":
    for r in snip["permissions"]["deny"]:
        if r not in deny:
            deny.append(r); added.append("deny " + r)
    for ev, entries in snip["hooks"].items():
        if only is not None and ev not in only:
            continue
        have = json.dumps(hooks.get(ev, []))
        for e in entries:
            script = e["hooks"][0]["command"].split("hooks/")[-1].rstrip('"')
            if MARK + script not in have:
                hooks.setdefault(ev, []).append(e); added.append("hook %s %s" % (ev, script))
else:
    cur["permissions"]["deny"] = [r for r in deny if r not in snip["permissions"]["deny"]]
    for ev in list(hooks):
        hooks[ev] = [e for e in hooks[ev] if MARK not in json.dumps(e)]
        if not hooks[ev]:
            del hooks[ev]
    added.append("removed token-optimisation entries")
if not cur["permissions"].get("deny"):
    cur["permissions"].pop("deny", None)
if not cur["permissions"]:
    del cur["permissions"]
if not cur.get("hooks"):
    cur.pop("hooks", None)
print("\n".join(added) or "settings: nothing to change")
if added and not dry:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        b = os.path.join(proj, ".claude", "token-optimisation", "backups", time.strftime("%Y%m%d-%H%M%S"))
        os.makedirs(b, exist_ok=True); shutil.copy2(path, os.path.join(b, "settings.json"))
    json.dump(cur, open(path, "w"), indent=2); open(path, "a").write("\n")
