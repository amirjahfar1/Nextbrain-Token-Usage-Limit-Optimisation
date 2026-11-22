"""Remove and check for the skill files (see files.py). Removes only what the manifest says we installed and the
project has not edited; links only when they point at our skill; folders only when they end up empty."""
import os, shutil, sys
from fcommon import *  # noqa: F401,F403
import fcommon as F
import state


def remove():
    st = state.load(proj)
    m = read_manifest()
    if not m and not any(managed(n) for _, n in SKILLS):
        print("  files: nothing installed here, nothing removed")
        return
    try: os.remove(man)
    except OSError: pass
    kept = []
    for _, name in SKILLS:
        d = os.path.join(sk, name)
        if not managed(name):
            continue
        for key, h in m.items():
            if key.startswith(name + "/"):
                t = os.path.join(sk, key)
                if os.path.lexists(t):
                    if state.sha(t) == h:
                        os.remove(t)
                    else:
                        kept.append(key)
        for extra in (".managed", "VERSION", "SOURCE", "INSTALLED_AT"):
            if name == "token-optimisation" or extra == ".managed":
                try: os.remove(os.path.join(d, extra))
                except OSError: pass
        for root, dirs, fs in os.walk(d, topdown=False):
            if os.path.basename(root) == "__pycache__":
                shutil.rmtree(root, ignore_errors=True)
            elif not os.listdir(root):
                os.rmdir(root)
        link = os.path.join(proj, ".claude", "skills", name)
        ours = name in st.get("files", {}).get("links", [])
        if os.path.islink(link) and os.readlink(link) == os.path.join("..", "..", ".agents", "skills", name):
            os.remove(link)
        elif os.path.isdir(link) and not os.path.islink(link) and ours:
            shutil.rmtree(link)
        elif os.path.lexists(link) and ours:
            print("  kept %s: no longer our link" % os.path.relpath(link, proj))
    f = st.get("files", {})
    # The conf, the .gitignore lines and the empty folders carry this system's own names: remove them even when an
    # older install did not record them (installed.json is newer than the first versions).
    if os.path.exists(CONF) and all(l.startswith(("#", "guard_mode=", "ranged=", "hooks=")) or not l.strip() for l in open(CONF)):
        os.remove(CONF)
    elif os.path.exists(CONF):
        print("  kept .agents/token-optimisation.conf (edited)")
    if "gitignore" not in f and os.path.exists(GI):
        f["gitignore"] = {"created": False, "text": "\n# token-optimisation local state\n" + GI_LINE + "\n"}
    gitignore(st, False)
    for d in reversed(f.get("dirs", [".agents", ".agents/skills", ".claude/skills"])):  # unrecorded = a pre-state install: guess
        state.rmdir_if_empty(os.path.join(proj, d))
    for k in kept:
        print("  kept locally edited: " + k)
    for key in ("links", "conf_created", "dirs"):
        f.pop(key, None)
    if not f:
        st.pop("files", None)
    st.pop("version", None)
    state.save(proj, st) if st else state.drop(proj)


def check():
    m = read_manifest()
    if not m:
        print("files: not installed"); sys.exit(1)
    bad = 0
    for k, h in sorted(m.items()):
        t = os.path.join(sk, k)
        if not os.path.exists(t):
            print("files: missing " + k); bad = 1
        elif state.sha(t) != h:
            print("files: locally edited " + k)
    try:
        have, want = open(os.path.join(sk, "token-optimisation", "VERSION")).read().strip(), open(os.path.join(repo, "VERSION")).read().strip()
        if have != want:
            print("files: update available (%s)" % want)
    except OSError:
        pass
    sys.exit(bad)
