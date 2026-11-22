#!/usr/bin/env python3
"""Routing map for a project, written to <project>/.claude/token-optimisation/ROUTES.md (+ ROUTES/ children when long):
  instructions (AGENTS.md, CLAUDE.md, skills, commands, rules ...), docs, each with its shards if a big file was split,
  then code areas. Usage: gen_routes.py [--force] [project_dir]. Rewrites only when the file list or a doc size changed.
It is the coarse layer above CODEMAP / code graph: find the file or area here, then go inside with a symbol tool or grep -n."""
import hashlib, os, shutil, subprocess, sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import routes_docs as rd

SKIP = {"node_modules", ".git", "dist", "build", ".next", ".venv", "venv", "__pycache__", ".index", "coverage",
        "target", "vendor", ".idea", ".vscode"}
BINARY = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".ico", ".woff", ".woff2", ".ttf", ".eot", ".pdf",
          ".zip", ".mp4", ".mp3", ".lock", ".map", ".min.js", ".DS_Store")
ENTRY = ("README.md", "readme.md", "index.ts", "index.tsx", "index.js", "index.py", "main.py", "main.ts", "main.go",
         "main.rs", "app.py", "__init__.py", "mod.rs", "lib.rs")
ROOT_KEEP = ("package.json", "pyproject.toml", "Cargo.toml", "go.mod", "Makefile", "docker-compose.yml", "Dockerfile",
             "requirements.txt", "install.sh", "VERSION")
SPLIT_AT, MAXROWS = 25, 40


def listing(root):
    try:
        out = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=root,
                             capture_output=True, check=True, timeout=5).stdout
        fs = [x.decode("utf-8", "surrogateescape") for x in out.split(b"\0") if x]
    except Exception:
        fs = []
        for r, ds, names in os.walk(root):
            ds[:] = [d for d in ds if d not in SKIP]
            fs += [os.path.relpath(os.path.join(r, n), root) for n in names]
    # .claude / .agents hold instructions, skills, commands: only their docs are listed, never settings or state
    return sorted(f for f in fs if not set(f.split("/")) & SKIP and not f.endswith(BINARY)
                  and (f.split("/")[0] not in (".claude", ".agents") or rd.is_doc(f)) and os.path.isfile(os.path.join(root, f)))


def split(prefix, fs, depth):
    sub, rows = {}, []
    loose = [f for f in fs if "/" not in f[len(prefix):]]
    for f in fs:
        rest = f[len(prefix):]
        if "/" in rest:
            sub.setdefault(rest.split("/")[0], []).append(f)
    for d, lst in sorted(sub.items()):
        rows += split(prefix + d + "/", lst, depth + 1) if len(lst) > SPLIT_AT and depth < 3 else [(prefix + d + "/", lst)]
    if prefix and loose and sub:
        rows.append((prefix + "*", loose))
    return rows


def row(root, path, fs):
    base = path.rstrip("*")
    kinds = Counter(os.path.splitext(f)[1] or "(none)" for f in fs).most_common(2)
    entry = next((e for e in ENTRY if base + e in fs), "")
    h = rd.info(root, base + entry)["title"] if entry.endswith(".md") else ""
    return "| `%s` | %d | %s | %s | %s |" % (path, len(fs), " ".join(k for k, _ in kinds), ("`%s`" % entry) if entry else "-", h or "-")


def build(root, fs, ins, docs, sig):
    out = {}
    code = [f for f in fs if f.split("/")[0] not in (".claude", ".agents")]
    rows = split("", code, 0)
    shown = sorted(sorted(rows, key=lambda r: -len(r[1]))[:MAXROWS])
    top = [f for f in code if "/" not in f]
    keep = [f for f in top if f in ROOT_KEEP]
    p = ["# Routing map (generated; do not edit)", "<!-- sig:%s -->" % sig,
         "Pick the file or area here, open only that one (a [split] file: only the shard you need), then CODEMAP / code graph / `grep -n` inside it.", ""]
    p += rd.section("instructions", "Instructions", ins, out) + [""] * bool(ins)
    p += rd.section("docs", "Docs", docs, out) + [""] * bool(docs)
    p += ["## Code and other areas", "| Area | Files | Kinds | Entry | What it is |", "|---|---|---|---|---|"]
    p += [row(root, a, l) for a, l in shown]
    if len(rows) > len(shown):
        p.append("| (%d smaller areas not listed) | | | | `ls` the parent folder |" % (len(rows) - len(shown)))
    p += ["", "Root files: " + (", ".join("`%s`" % f for f in keep) or "none") + ("; %d others" % (len(top) - len(keep)) if len(top) > len(keep) else "")]
    out["ROUTES.md"] = "\n".join(p) + "\n"
    return out


def refresh(root, force=False):
    """Returns created | updated | same | empty."""
    fs = listing(root)
    if not fs:
        return "empty"
    ins, docs = rd.collect(root, fs)
    h = hashlib.sha256("\n".join(fs + ["%s:%d" % (i["f"], i["b"]) for i in ins + docs]).encode("utf-8", "surrogateescape")).hexdigest()[:16]
    d = os.path.join(root, ".claude", "token-optimisation")
    old = None
    try:
        old = open(os.path.join(d, "ROUTES.md")).read(600)
    except OSError:
        pass
    if old and ("sig:%s" % h) in old and not force:
        return "same"
    out = build(root, fs, ins, docs, h)
    shutil.rmtree(os.path.join(d, "ROUTES"), ignore_errors=True)  # children of an older map
    for rel, text in sorted(out.items(), reverse=True):  # children first, ROUTES.md (with the sig) last
        t = os.path.join(d, rel)
        os.makedirs(os.path.dirname(t), exist_ok=True)
        open(t + ".tmp", "w").write(text)
        os.replace(t + ".tmp", t)
    return "updated" if old else "created"


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    r = os.path.abspath(a[0] if a else ".")
    print("routes: %s (%s)" % (refresh(r, "--force" in sys.argv), os.path.join(r, ".claude/token-optimisation/ROUTES.md")))
