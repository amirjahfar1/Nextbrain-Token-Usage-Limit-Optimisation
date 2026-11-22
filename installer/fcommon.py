"""Shared by files.py and files_rm.py: arguments, paths and small helpers for the skill files."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import state

SKILLS = [("skill", "token-optimisation"), ("skill-tips", "tips"), ("skill-audit", "token-audit"), ("skill-handoff", "handoff")]
SKIP = ("__pycache__", ".DS_Store")
repo, proj, op = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2]), sys.argv[3]
hooks_arg = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--hooks=")), None)
sk = os.path.join(proj, ".agents", "skills")
man = os.path.join(sk, "token-optimisation", ".manifest")
CONF = os.path.join(proj, ".agents", "token-optimisation.conf")
CONF_TEXT = "# project overrides for token-optimisation (defaults: skill/config/defaults.conf)\nguard_mode=log\nranged=\n"
GI = os.path.join(proj, ".gitignore")
GI_LINE = ".claude/token-optimisation/"
dry = op == "dry"


def src_files(d):
    out = []
    for root, dirs, fs in os.walk(d):
        dirs[:] = [x for x in dirs if x not in SKIP]
        out += [os.path.relpath(os.path.join(root, f), d) for f in fs if f not in SKIP and not f.endswith(".pyc")]
    return sorted(out)


def read_manifest():
    m = {}
    try:
        for l in open(man):
            h, _, k = l.rstrip("\n").partition("  ")
            if h and k:
                m[k] = h
    except OSError:
        pass
    return m


def managed(name):
    return os.path.exists(os.path.join(sk, name, ".managed"))


def shell_quote(s):
    return "'" + s.replace("'", "'\\''") + "'"


def write_conf(st):
    if not os.path.exists(CONF) and not dry:
        os.makedirs(os.path.dirname(CONF), exist_ok=True)
        open(CONF, "w").write(CONF_TEXT)
        st.setdefault("files", {})["conf_created"] = True
    if hooks_arg and not dry:
        lines = [l for l in open(CONF).read().splitlines() if not l.startswith("hooks=")] + ["hooks=" + hooks_arg]
        open(CONF, "w").write("\n".join(lines) + "\n")


def gitignore(st, add):
    f = st.setdefault("files", {})
    if add:
        cur = open(GI, "rb").read().decode("utf-8", "replace") if os.path.exists(GI) else None
        if cur is not None and any(l.startswith(".claude/token-optimisation") for l in cur.splitlines()):
            return
        text = ("" if cur is None or cur.endswith("\n") or not cur else "\n") + "\n# token-optimisation local state\n" + GI_LINE + "\n"
        if not dry:
            open(GI, "a").write(text)
            f["gitignore"] = {"created": cur is None, "text": text}
    else:
        g = f.get("gitignore")
        if not g or not os.path.exists(GI):
            return
        cur = open(GI).read()
        new = cur[:-len(g["text"])] if cur.endswith(g["text"]) else "".join(l for l in cur.splitlines(True) if l.strip() not in (GI_LINE, "# token-optimisation local state"))
        if not new.strip():  # nothing but our lines was in it: do not leave an empty file behind
            os.remove(GI)
        else:
            open(GI, "w").write(new)
        f.pop("gitignore", None)
