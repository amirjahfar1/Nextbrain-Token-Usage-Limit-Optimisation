"""Shared helpers for hooks. Hooks fail open: any error means exit 0 with no output."""
import fnmatch, json, os, sys

SKILL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_input():
    try:
        return json.loads(sys.stdin.read() or "{}")
    except ValueError:
        return {}


def conf(cwd):
    out = {}
    for p in (os.path.join(SKILL, "config", "defaults.conf"), os.path.join(cwd, ".agents", "token-optimisation.conf")):
        try:
            for l in open(p):
                if "=" in l and not l.startswith("#"):
                    k, v = l.split("=", 1)
                    out[k.strip()] = v.strip()
        except OSError:
            pass
    return out


def listing(v):
    return [x.strip() for x in (v or "").split(",") if x.strip()]


def match(rel, pats):
    return any(fnmatch.fnmatch(rel, p) or fnmatch.fnmatch("/" + rel, p) or fnmatch.fnmatch(rel, p.replace("**/", "")) for p in pats)


def state_dir(cwd):
    return os.path.join(cwd, ".claude", "token-optimisation")


def guarded(fn):
    if os.environ.get("TOKEN_OPT_OFF") == "1":
        return
    try:
        fn()
    except Exception:
        pass
    sys.exit(0)
