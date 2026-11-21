#!/usr/bin/env python3
"""SessionStart: one plain stdout line (reaches the agent) when a review is pending or a resume is stale."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import guarded, load_input, state_dir


def run():
    d = load_input()
    sd = state_dir(d.get("cwd") or os.getcwd())
    pr = os.path.join(sd, "pending-review")
    if os.path.exists(pr):
        print("token-optimisation: the previous session was flagged expensive. Offer the owner the "
              "session-review workflow (rules/session-review.md). Report: " + pr)
    elif d.get("source") == "resume" and d.get("prompt_cache_likely_expired"):
        print("token-optimisation: resumed after a long break; the prompt cache has likely expired. "
              "Suggest a checkpoint and a fresh chat (rules/session.md S2, S4).")


guarded(run)
