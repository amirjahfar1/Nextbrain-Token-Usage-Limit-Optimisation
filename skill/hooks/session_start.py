#!/usr/bin/env python3
"""SessionStart: one plain stdout line (reaches the agent) when a review is pending or a resume is stale."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import SKILL, conf, guarded, load_input, project_dir, state_dir


def routes(root):
    """Keep the project's routing map fresh (rewritten only when the file list changed); say so once per change."""
    if conf(root).get("routes", "1") == "0":
        return
    sys.path.insert(0, os.path.join(SKILL, "scripts"))
    from gen_routes import refresh
    if refresh(root) in ("created", "updated"):
        print("token-optimisation: routing map refreshed: .claude/token-optimisation/ROUTES.md. To find where "
              "something lives, open it first, then CODEMAP / code graph / grep -n inside that area.")


def run():
    d = load_input()
    try:
        routes(project_dir(d))
    except Exception:
        pass
    sd = state_dir(project_dir(d))
    pr = os.path.join(sd, "pending-review")
    if os.path.exists(pr):
        shown = pr + ".shown"  # say it once: the next session must not repeat it
        try:
            os.replace(pr, shown)
        except OSError:
            shown = pr
        print("token-optimisation: the previous session was flagged expensive. Offer the owner the "
              "session-review workflow (rules/session-review.md). Report: " + shown)
    elif d.get("source") == "resume" and d.get("prompt_cache_likely_expired"):
        print("token-optimisation: resumed after a long break; the prompt cache has likely expired. "
              "Suggest a checkpoint and a fresh chat (rules/session.md S2, S4).")


guarded(run)
