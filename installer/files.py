#!/usr/bin/env python3
"""Skill files, links, conf and .gitignore line. Usage:
  files.py <repo> <project> preflight|install|update|remove|check|dry [--hooks=MODE]
Manifest (.agents/skills/token-optimisation/.manifest) holds the hash of each file as installed FROM THE REPO, so a
local edit is always detectable: update keeps edited files, remove (files_rm.py) deletes only unedited files we
installed. What we create (dirs, links, conf, .gitignore text) is recorded in installed.json and removed exactly."""
import os, re, shutil, sys, time
from fcommon import *  # noqa: F401,F403
import state


def preflight():
    d = os.path.join(sk, "token-optimisation")
    if os.path.lexists(d) and not managed("token-optimisation"):
        sys.exit("files: %s already exists and is not managed by this installer. Nothing was written. Merge by hand (ADOPTION.md)." % os.path.relpath(d, proj))
    if os.path.lexists(sk) and not os.path.isdir(sk):
        sys.exit("files: .agents/skills exists and is not a folder. Nothing was written.")


def install():
    old, new = read_manifest(), {}
    st = state.load(proj)
    files = st.setdefault("files", {})
    if old and "dirs" not in files:  # installed before installed.json: those folders were most likely ours
        files["dirs"] = [".agents", ".agents/skills", ".claude/skills"]
    files.setdefault("dirs", [])
    for d in (".agents", ".agents/skills", ".claude", ".claude/skills"):
        if not os.path.lexists(os.path.join(proj, d)) and d not in files["dirs"]:
            files["dirs"].append(d)
    notes = []
    for srcname, name in SKILLS:
        srcdir, d = os.path.join(repo, srcname), os.path.join(sk, name)
        if os.path.lexists(d) and not managed(name):
            notes.append("  kept existing unmanaged skill: %s (merge it in ADOPTION.md)" % name)
            continue
        names = src_files(srcdir)
        n = 0
        for rel in names:
            f, t, key = os.path.join(srcdir, rel), os.path.join(d, rel), name + "/" + rel
            h = state.sha(f)
            if os.path.lexists(t):
                disk, oldh = state.sha(t), old.get(key)
                if op == "update" and oldh and disk != oldh and disk != h:
                    notes.append("  kept locally edited: " + key)
                    new[key] = oldh
                    continue
            n += 1
            if dry:
                continue
            os.makedirs(os.path.dirname(t), exist_ok=True)
            shutil.copy2(f, t)
            new[key] = h
        if dry:
            print("  would write skill %s (%d files)" % (name, n))
            continue
        for key, oldh in old.items():  # a file the repo no longer has: drop it if the project did not edit it
            if key.startswith(name + "/") and key[len(name) + 1:] not in names:
                t = os.path.join(sk, key)
                if os.path.exists(t) and state.sha(t) == oldh:
                    os.remove(t)
        open(os.path.join(d, ".managed"), "w").close()
    for note in notes:
        print(note)
    if dry:
        print("  would write .agents/token-optimisation.conf, symlinks in .claude/skills, a .gitignore line, installed.json, and copies of changed files under .claude/token-optimisation/backups")
        return
    ti = os.path.join(sk, "token-optimisation")
    shutil.copy2(os.path.join(repo, "VERSION"), os.path.join(ti, "VERSION"))
    new["token-optimisation/VERSION"] = state.sha(os.path.join(ti, "VERSION"))
    url = os.popen("git -C %s remote get-url origin 2>/dev/null" % shell_quote(repo)).read().strip()
    url = re.sub(r"//[^/@]*@", "//", url) or "https://github.com/amirjahfar1/Nextbrain-Token-Usage-Limit-Optimisation.git"
    open(os.path.join(ti, "SOURCE"), "w").write(url + "\n")
    new["token-optimisation/SOURCE"] = state.sha(os.path.join(ti, "SOURCE"))
    at = os.path.join(ti, "INSTALLED_AT")
    if not os.path.exists(at):
        open(at, "w").write(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()) + "\n")
    with open(man, "w") as f:
        for k in sorted(new):
            f.write("%s  %s\n" % (new[k], k))
    write_conf(st)
    links = files.setdefault("links", [])
    for _, name in SKILLS:
        dst = os.path.join(proj, ".claude", "skills", name)
        if not managed(name) or os.path.lexists(dst):
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        try:
            os.symlink(os.path.join("..", "..", ".agents", "skills", name), dst)
        except OSError:
            shutil.copytree(os.path.join(sk, name), dst)
        links.append(name)
    gitignore(st, True)
    state.save(proj, st)


if op in ("remove", "check"):
    import files_rm
    {"remove": files_rm.remove, "check": files_rm.check}[op]()
else:
    {"preflight": preflight, "install": install, "update": install, "dry": install}[op]()
