#!/usr/bin/env python3
"""hookcmd.py SETTINGS SCRIPT: print the installed hook command that runs SCRIPT."""
import json, sys
s = json.load(open(sys.argv[1]))
for ev, groups in (s.get("hooks") or {}).items():
    for g in groups:
        for h in g.get("hooks", []):
            if sys.argv[2] in h.get("command", ""):
                print(h["command"]); sys.exit(0)
sys.exit(1)
