#!/usr/bin/env python3
"""PreToolUse(Read): block or log full reads of big or guarded files. Modes: off | log | deny."""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import conf, guarded, listing, load_input, match, state_dir


def run():
    d = load_input()
    ti = d.get("tool_input") or {}
    cwd = d.get("cwd") or os.getcwd()
    path = ti.get("file_path") or ""
    c = conf(cwd)
    mode = c.get("guard_mode", "log")
    if mode == "off" or not path:
        return
    rel = os.path.relpath(path, cwd) if os.path.isabs(path) else path
    ranged = bool(ti.get("limit"))
    why = None
    if match(rel, listing(c.get("never"))):
        why = "this file class is never opened (lockfile, build or minified output). Query it: grep -n -m 20, or the package manager."
    elif not ranged:
        try:
            big = os.path.getsize(path) > int(c.get("max_read_bytes", "60000"))
        except (OSError, ValueError):
            big = False
        if match(rel, listing(c.get("ranged"))) or big:
            why = ("big file read without a range. Use Read with offset+limit, or "
                   "`python3 .agents/skills/token-optimisation/scripts/bigfile.py get <file> <key>` (see rules/bigfiles.md).")
    if not why:
        return
    sd = state_dir(cwd)
    os.makedirs(sd, exist_ok=True)
    with open(os.path.join(sd, "guard.log"), "a") as f:
        f.write("%d\t%s\t%s\t%s\n" % (time.time(), mode, rel, "range" if ranged else "full"))
    if mode == "deny":
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                          "permissionDecisionReason": "token-optimisation: " + why}}))


guarded(run)
