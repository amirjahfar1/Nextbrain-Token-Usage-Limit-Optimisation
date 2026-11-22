#!/usr/bin/env python3
"""PreToolUse(Read): block or log full reads of big or guarded files. Modes: off | log | deny.
Only files inside the project are judged. A small file read with a range is never blocked, so Edit keeps working."""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import conf, guarded, listing, load_input, match, project_dir, state_dir


def run():
    d = load_input()
    ti = d.get("tool_input") or {}
    proj = project_dir(d)
    path = ti.get("file_path") or ""
    c = conf(proj)
    mode = c.get("guard_mode", "log")
    if mode == "off" or not path:
        return
    ap = path if os.path.isabs(path) else os.path.join(d.get("cwd") or proj, path)
    rel = os.path.relpath(ap, proj)
    if rel.startswith(".."):
        return
    ranged = bool(ti.get("limit"))
    try:
        big = os.path.getsize(ap) > int(c.get("max_read_bytes", "60000"))
    except (OSError, ValueError):
        big = False
    why = None
    if match(rel, listing(c.get("never"))):
        if big or not ranged:
            why = "this file class is never opened whole (lockfile, build or minified output). Query it: grep -n -m 20, or the package manager."
    elif not ranged and (match(rel, listing(c.get("ranged"))) or big):
        why = ("big file read without a range. Use Read with offset+limit, or "
               "`python3 .agents/skills/token-optimisation/scripts/bigfile.py get <file> <key>` (see rules/bigfiles.md).")
    if not why:
        return
    sd = state_dir(proj)
    os.makedirs(sd, exist_ok=True)
    with open(os.path.join(sd, "guard.log"), "a") as f:
        f.write("%d\t%s\t%s\t%s\n" % (time.time(), mode, rel, "range" if ranged else "full"))
    if mode == "deny":
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                          "permissionDecisionReason": "token-optimisation: " + why}}))


guarded(run)
