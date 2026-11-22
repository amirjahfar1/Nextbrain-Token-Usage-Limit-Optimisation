"""Docs and instructions part of the routing map (used by gen_routes.py): every doc and instruction file, where it
lives, what it is, and the shards (with their sections) of a big file that was split into smaller files."""
import os, re

DOC_EXT = (".md", ".mdx", ".rst", ".mdc")
OWN = ("token-optimisation", "tips", "token-audit", "handoff")  # this system's own skills are never listed
INSTR_FILES = ("AGENTS.md", "CLAUDE.md", "CLAUDE.local.md", "GEMINI.md", "SKILL.md", "copilot-instructions.md")
INSTR_DIRS = ("skills", "commands", "agents", "rules", "instructions", "prompts")
HIDDEN = (".claude", ".agents", ".cursor", ".github", ".codex", ".windsurf")
BIG_LINES, BIG_BYTES, INLINE, ONE_CHILD = 100, 6144, 30, 80
PTR = ".claude/token-optimisation/ROUTES/"


def is_doc(f):
    p = f.split("/")
    if not f.endswith(DOC_EXT):
        return False
    return not (p[0] in (".claude", ".agents") and len(p) > 2 and (p[1] == "token-optimisation" or (p[1] == "skills" and p[2] in OWN)))


def is_instr(f):
    p = f.split("/")
    return (p[-1] in INSTR_FILES or p[-1].endswith(".mdc") or any(x in ("instructions", "rules") for x in p[:-1])
            or (p[0] in HIDDEN and any(x in INSTR_DIRS for x in p[1:-1])) or bool(re.search(r"instruction|guideline", p[-1], re.I)))


def title(t):
    for line in t.split("\n")[:14]:
        s = line.strip().lstrip("#").strip()
        if s.startswith("description:"):
            s = s[12:].strip().strip('"')
        if s and not s.startswith(("---", "<!--", "name:")):
            return s[:70].replace("|", "/")
    return ""


def info(root, f):
    try:
        t = open(os.path.join(root, f), errors="replace").read(300000)
    except OSError:
        return None
    d, sh = os.path.dirname(f), []
    if "Split into small files" in t:
        sh = [(os.path.normpath(os.path.join(d, a)).replace(os.sep, "/"), b) for a, b in re.findall(r"^- \[[^\]]+\]\(([^)]+)\): (.*)$", t, re.M)]
    return {"f": f, "n": t.count("\n") + 1, "b": len(t), "title": title(t), "shards": sh}


def collect(root, fs):
    """-> (instructions, docs): shard files are not listed on their own, they hang under their parent."""
    infos = [i for i in (info(root, f) for f in fs if is_doc(f)) if i]
    child = {s for i in infos for s, _ in i["shards"]}
    rest = [i for i in infos if i["f"] not in child]
    return [i for i in rest if is_instr(i["f"])], [i for i in rest if not is_instr(i["f"])]


def lines(i):
    note = " [split: %d shards]" % len(i["shards"]) if i["shards"] else (
        " [BIG: split-md or ranged read]" if i["n"] > BIG_LINES or i["b"] > BIG_BYTES else "")
    return ["- `%s` (%d lines): %s%s" % (i["f"], i["n"], i["title"] or "-", note)] + [
        "  - `%s`: %s" % (s, sec[:80]) for s, sec in i["shards"][:15]]


def section(name, label, infos, out):
    """Parent-map lines for one section; a long section moves to its own child file(s) in `out` (path -> text)."""
    if not infos:
        return []
    groups = {}
    for i in sorted(infos, key=lambda x: x["f"]):
        groups.setdefault(i["f"].split("/")[0] if "/" in i["f"] else ".", []).append(lines(i))
    flat = [l for k in sorted(groups) for ls in groups[k] for l in ls]
    head = "## %s (%d files)" % (label, len(infos))
    if len(flat) <= INLINE:
        return [head] + flat
    if len(flat) > ONE_CHILD:
        idx = []
        for k in sorted(groups):
            fn = "%s-%s.md" % (name, re.sub(r"[^A-Za-z0-9]+", "-", k).strip("-") or "root")
            out["ROUTES/" + fn] = "# %s: %s\n%s\n" % (label, k, "\n".join(l for ls in groups[k] for l in ls))
            idx.append("- `%s%s`: %d files under `%s`" % (PTR, fn, len(groups[k]), k))
        out["ROUTES/%s.md" % name] = "# %s\nOpen only the folder you need:\n%s\n" % (label, "\n".join(idx))
        return [head, "Open `%s%s.md`, then the one folder you need." % (PTR, name)]
    out["ROUTES/%s.md" % name] = "# %s\n%s\n" % (label, "\n".join(flat))
    return [head, "Open `%s%s.md` for the list." % (PTR, name)]
