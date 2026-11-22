#!/usr/bin/env python3
"""settings_check.py ORIG NEW: every original key/hook/permission still there, unchanged and in order; ours added exactly once."""
import json, sys
o, n = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
bad = []
for k, v in o.items():
    if k in ("permissions", "hooks"): continue
    if n.get(k) != v: bad.append("top-level key changed: " + k)
if list(o)[:len(o)] != [k for k in n if k in o]: bad.append("top-level key order changed")
op, np_ = o.get("permissions") or {}, n.get("permissions") or {}
for k, v in op.items():
    if k == "deny":
        if np_.get("deny", [])[:len(v)] != v: bad.append("original deny rules changed or reordered")
    elif np_.get(k) != v: bad.append("permissions.%s changed" % k)
d = np_.get("deny", [])
if len(d) != len(set(d)): bad.append("duplicate deny rules")
oh, nh = o.get("hooks") or {}, n.get("hooks") or {}
for ev, v in oh.items():
    if nh.get(ev, [])[:len(v)] != v: bad.append("original hooks for %s changed or reordered" % ev)
for ev, want in (("PreToolUse", "guard_read.py"), ("SessionStart", "session_start.py"), ("SessionEnd", "session_end.py")):
    c = json.dumps(nh.get(ev, [])).count("token-optimisation/hooks/" + want)
    if c != 1: bad.append("our %s hook present %d times" % (want, c))
print("\n".join(bad) or "settings ok"); sys.exit(1 if bad else 0)
