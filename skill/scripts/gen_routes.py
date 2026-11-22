#!/usr/bin/env python3
"""Routing map: area -> kind -> entry file -> what it is. Writes <project>/.claude/token-optimisation/ROUTES.md.
Usage: gen_routes.py [--force] [project_dir]. Rewrites only when the file list changed. It is the coarse layer
above CODEMAP / code graph (symbols): find the area here first, then ask the symbol tool or grep -n inside it."""
import hashlib, os, subprocess, sys
from collections import Counter

SKIP = {"node_modules", ".git", "dist", "build", ".next", ".venv", "venv", "__pycache__", ".claude", ".agents",
        ".index", "coverage", "target", "vendor", ".idea", ".vscode"}
BINARY = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".ico", ".woff", ".woff2", ".ttf", ".eot", ".pdf",
          ".zip", ".mp4", ".mp3", ".lock", ".map", ".min.js", ".DS_Store")
ENTRY = ("README.md", "readme.md", "SKILL.md", "AGENTS.md", "CLAUDE.md", "index.ts", "index.tsx", "index.js",
         "index.py", "main.py", "main.ts", "main.go", "main.rs", "app.py", "__init__.py", "mod.rs", "lib.rs")
ROOT_KEEP = ("README.md", "AGENTS.md", "CLAUDE.md", "package.json", "pyproject.toml", "Cargo.toml", "go.mod",
             "Makefile", "docker-compose.yml", "Dockerfile", "requirements.txt", "install.sh", "VERSION")
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
    return sorted(f for f in fs if not set(f.split("/")) & SKIP and not f.endswith(BINARY)
                  and os.path.isfile(os.path.join(root, f)))


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


def hint(root, path):
    try:
        for line in open(os.path.join(root, path), errors="replace"):
            t = line.strip().lstrip("#").strip()
            if t.startswith("description:"):
                t = t[12:].strip().strip('"')
            if t and not t.startswith(("---", "<!--", "name:")):
                return t[:60].replace("|", "/")
    except OSError:
        pass
    return ""


def row(root, path, fs):
    base = path.rstrip("*")
    kinds = Counter(os.path.splitext(f)[1] or "(none)" for f in fs).most_common(2)
    entry = next((e for e in ENTRY if base + e in fs), "")
    h = hint(root, base + entry) if entry.endswith(".md") else ""
    return "| `%s` | %d | %s | %s | %s |" % (path, len(fs), " ".join(k for k, _ in kinds), ("`%s`" % entry) if entry else "-", h or "-")


def build(root, fs, sig):
    rows = split("", fs, 0)
    shown = sorted(sorted(rows, key=lambda r: -len(r[1]))[:MAXROWS])
    top = [f for f in fs if "/" not in f]
    keep = [f for f in top if f in ROOT_KEEP]
    out = ["# Routing map (generated; do not edit)", "<!-- sig:%s -->" % sig,
           "Find the area here, then use CODEMAP / code graph / `grep -n` inside it. Open one file, not the folder.", "",
           "| Area | Files | Kinds | Entry | What it is |", "|---|---|---|---|---|"]
    out += [row(root, p, l) for p, l in shown]
    if len(rows) > len(shown):
        out.append("| (%d smaller areas not listed) | | | | `ls` the parent folder |" % (len(rows) - len(shown)))
    out += ["", "Root files: " + (", ".join("`%s`" % f for f in keep) or "none") + (
        "; %d others" % (len(top) - len(keep)) if len(top) > len(keep) else "")]
    return "\n".join(out) + "\n"


def refresh(root, force=False):
    """Returns created | updated | same | empty."""
    fs = listing(root)
    if not fs:
        return "empty"
    sig = hashlib.sha256("\n".join(fs).encode("utf-8", "surrogateescape")).hexdigest()[:16]
    p = os.path.join(root, ".claude", "token-optimisation", "ROUTES.md")
    old = None
    try:
        old = open(p).read(400)
    except OSError:
        pass
    if old and ("sig:%s" % sig) in old and not force:
        return "same"
    os.makedirs(os.path.dirname(p), exist_ok=True)
    tmp = p + ".tmp"
    open(tmp, "w").write(build(root, fs, sig))
    os.replace(tmp, p)
    return "updated" if old else "created"


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    r = os.path.abspath(a[0] if a else ".")
    print("routes: %s (%s)" % (refresh(r, "--force" in sys.argv), os.path.join(r, ".claude/token-optimisation/ROUTES.md")))
