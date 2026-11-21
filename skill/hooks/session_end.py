#!/usr/bin/env python3
"""SessionEnd: record the session cost row; write pending-review when flagged."""
import os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import SKILL, guarded, load_input, state_dir


def run():
    d = load_input()
    tp = d.get("transcript_path")
    if not tp or not os.path.exists(tp):
        return
    sd = state_dir(d.get("cwd") or os.getcwd())
    subprocess.run([sys.executable, os.path.join(SKILL, "scripts", "cost_report.py"), tp, "--record", sd],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=12)


guarded(run)
