#!/usr/bin/env python3
"""The always-on block in the entry file. Usage: block.py <project> insert|remove|where [--dry-run]
Markers count only as whole lines. Unbalanced markers abort without writing. An existing block is replaced in
place. What we added (a blank line, a created file, a missing final newline) is recorded in installed.json so
remove restores the file byte for byte. Claude Code loads CLAUDE.md; AGENTS.md is read by other agents, so a
project with only AGENTS.md also gets a CLAUDE.md that imports it."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import state

B = b"<!-- TOKEN-OPTIMISATION:BEGIN -->"
E = b"<!-- TOKEN-OPTIMISATION:END -->"
IMPORT = b"@AGENTS.md\n"
here = os.path.dirname(os.path.abspath(__file__))
proj, mode = os.path.abspath(sys.argv[1]), sys.argv[2]
dry = "--dry-run" in sys.argv
cl, ag = os.path.join(proj, "CLAUDE.md"), os.path.join(proj, "AGENTS.md")

def read(p):
    try:
        return open(p, "rb").read()
    except OSError:
        return None

def real(p):
    return os.path.realpath(p)

def choose():
    """(file to hold the block, whether it is new, whether CLAUDE.md must be created to import it)."""
    if os.path.lexists(cl):
        t = read(cl) or b""
        imports = any(l.strip() == b"@AGENTS.md" for l in t.splitlines())
        if os.path.lexists(ag) and (real(ag) == real(cl) or imports):
            return real(ag), False, False
        return real(cl), False, False
    if os.path.lexists(ag):
        return real(ag), False, True
    return ag, True, True

def find(lines):
    bs = [i for i, l in enumerate(lines) if l.rstrip(b"\r\n") == B]
    es = [i for i, l in enumerate(lines) if l.rstrip(b"\r\n") == E]
    if not bs and not es:
        return None
    if len(bs) == 1 and len(es) == 1 and bs[0] < es[0]:
        return bs[0], es[0]
    sys.exit("block: the markers in this file are unbalanced (%d begin, %d end); not touching it. Fix by hand." % (len(bs), len(es)))

def block_bytes(nl):
    body = open(os.path.join(here, "block.md"), "rb").read().replace(b"\r\n", b"\n").rstrip(b"\n")
    return nl.join([B, b"## Token optimisation"] + body.split(b"\n") + [E]) + nl

def write(p, data):
    if dry:
        print("  would write", os.path.relpath(p, proj))
        return
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "wb").write(data)

st = state.load(proj)
ent = st.get("entry", {})

if mode == "where":
    print(choose()[0])
elif mode == "insert":
    path, created, need_cl = choose()
    old = read(path)
    old = b"" if old is None else old
    nl = b"\r\n" if b"\r\n" in old else b"\n"
    lines = old.splitlines(keepends=True)
    span = find(lines)
    blk = block_bytes(nl)
    rec = ent if ent.get("file") == os.path.relpath(path, proj) else {}
    if span:
        new = b"".join(lines[:span[0]]) + blk + b"".join(lines[span[1] + 1:])
        if new == old:
            print("  block: already current in " + os.path.relpath(path, proj))
        else:
            if not dry: state.backup(proj, path, os.path.basename(path))
            write(path, new)
            print("  block: replaced in " + os.path.relpath(path, proj))
    else:
        had_nl = old.endswith(b"\n") or not old
        if not old:
            lead = b""
        elif not had_nl:
            lead = nl + nl
        elif old.endswith(nl + nl):
            lead = b""
        else:
            lead = nl
        if not dry and old: state.backup(proj, path, os.path.basename(path))
        write(path, old + lead + blk)
        rec = {"file": os.path.relpath(path, proj), "created": created, "lead": len(lead), "no_final_nl": not had_nl}
        print("  block: added to " + os.path.relpath(path, proj) + (" (new file)" if created else ""))
    if need_cl and not os.path.lexists(cl) and "claude_created" not in ent:
        write(cl, IMPORT)
        rec["claude_created"] = True
        print("  CLAUDE.md: created with @AGENTS.md so Claude Code loads the block")
    elif ent.get("claude_created"):
        rec["claude_created"] = True
    if not dry and rec:
        st["entry"] = rec
        state.save(proj, st)
elif mode == "remove":
    targets = []
    if ent.get("file"):
        targets.append(os.path.join(proj, ent["file"]))
    for p in (cl, ag):
        if os.path.lexists(p) and real(p) not in [real(t) for t in targets if os.path.lexists(t)]:
            targets.append(p)
    for p in targets:
        p = real(p)
        data = read(p)
        if data is None:
            continue
        lines = data.splitlines(keepends=True)
        span = find(lines)
        if not span:
            continue
        rest = lines[:span[0]] + lines[span[1] + 1:]
        if ent.get("file") and real(os.path.join(proj, ent["file"])) == p:
            if ent.get("lead") and rest and rest[-1].strip() == b"":
                rest.pop()
            new = b"".join(rest)
            if ent.get("no_final_nl") and new.endswith((b"\r\n", b"\n")):
                new = new[:-2] if new.endswith(b"\r\n") else new[:-1]
        else:
            if rest and rest[-1].strip() == b"":  # an install from before installed.json always added one blank line
                rest.pop()
            new = b"".join(rest)
        if ent.get("created") and ent.get("file") and real(os.path.join(proj, ent["file"])) == p and not new.strip():
            if not dry: os.remove(p)
            print("  block: removed, deleted the file we created: " + os.path.relpath(p, proj))
        else:
            if not dry: state.backup(proj, p, os.path.basename(p))
            write(p, new)
            print("  block: removed from " + os.path.relpath(p, proj))
    if ent.get("claude_created") and read(cl) == IMPORT:
        if not dry: os.remove(cl)
        print("  CLAUDE.md: removed (we created it)")
    if not dry:
        st.pop("entry", None)
        state.save(proj, st) if st else state.drop(proj)
