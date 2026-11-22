#!/usr/bin/env python3
"""Big-file tools: scan | index <file> | get <file> <key> | split-md <file> [--apply]"""
import hashlib, os, re, subprocess, sys

CHUNK, ROWS, CAP = 100, 60, 120
SKIP = ("node_modules", ".git", "dist", ".claude", ".index")
BINARY = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".ico", ".woff", ".woff2", ".ttf", ".eot", ".pdf", ".zip", ".mp4", ".mp3")


def lines_of(p):
    return open(p, errors="replace").read().split("\n")


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()[:16]


def listing():
    """Project files: git's list (tracked and untracked, honouring .gitignore, NUL separated so any name works),
    else a walk that skips whole folders by name."""
    try:
        out = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], capture_output=True, check=True).stdout
        return [x.decode("utf-8", "surrogateescape") for x in out.split(b"\0") if x]
    except Exception:
        out = []
        for r, ds, fs in os.walk("."):
            ds[:] = [x for x in ds if x not in SKIP]
            out += [os.path.relpath(os.path.join(r, f)) for f in fs]
        return out


def scan():
    for f in listing():
        if any(part in SKIP for part in f.split(os.sep)) or f.lower().endswith(BINARY) or not os.path.isfile(f):
            continue
        n, b = os.path.getsize(f), os.path.splitext(f)[1]
        ln = len(lines_of(f)) if n < 5_000_000 else 0
        if n < 40000 and ln < 120:
            continue
        cls = "never" if f.endswith((".lock", "-lock.json", "-lock.yaml", ".min.js", ".map")) else "split" if b == ".md" else "ranged"
        print("%s\t%d lines\t%d bytes\t-> %s" % (f, ln, n, cls))


def title(chunk):
    for l in chunk:
        m = re.search(r'"(?:id|name|title)"\s*:\s*"([^"]+)"', l) or re.match(r"#+\s+(.*)", l)
        if m:
            return m.group(1)[:60]
    return next((l.strip()[:60] for l in chunk if l.strip()), "")


def index(f):
    ls = lines_of(f)
    rows = [(i // CHUNK, i + 1, min(i + CHUNK, len(ls)), title(ls[i:i + CHUNK])) for i in range(0, len(ls), CHUNK)]
    d = f + ".index"
    os.makedirs(d, exist_ok=True)
    head = "# sha256=%s lines=%d chunk=%d\n" % (sha(f), len(ls), CHUNK)
    shards = [rows[i:i + ROWS] for i in range(0, len(rows), ROWS)]
    for n, s in enumerate(shards):
        open("%s/%02d.tsv" % (d, n), "w").write(head + "".join("%d\t%d\t%d\t%s\n" % r for r in s))
    open(d + "/00-parent.tsv", "w").write(head + "".join("%02d.tsv\tkeys %d-%d\n" % (n, s[0][0], s[-1][0]) for n, s in enumerate(shards)))
    print("indexed %s: %d chunks in %d shard(s)" % (f, len(rows), len(shards)))


def get(f, key):
    d, found = f + ".index", None
    shards = sorted(x for x in os.listdir(d) if re.match(r"\d\d\.tsv$", x) and x != "00-parent.tsv") if os.path.isdir(d) else []
    if not shards:
        sys.exit("no index: run bigfile.py index " + f)
    for s in shards:
        L = open(os.path.join(d, s)).read().split("\n")
        if "sha256=" + sha(f) not in L[0]:
            sys.exit("index is stale: run bigfile.py index " + f)
        for r in L[1:]:
            p = r.split("\t")
            if len(p) == 4 and (p[0] == key or key.lower() in p[3].lower()):
                found = found or p
    if not found:
        sys.exit("key not found; see " + d)
    a, b = int(found[1]), int(found[2])
    ls = lines_of(f)
    print("# %s lines %d-%d (%s)" % (f, a, min(b, a + CAP - 1), found[3]))
    print("\n".join(ls[a - 1:min(b, a + CAP - 1)]))


def fix_links(text):
    """Shards live one folder deeper: prefix relative markdown links with ../ (anchors and URLs untouched)."""
    return re.sub(r"\]\((?!https?:|#|/|mailto:|\.\./)([^)\s]+)\)", r"](../\1)", text)


def split_md(f, apply):
    ls = lines_of(f)
    cuts = [i for i, l in enumerate(ls) if l.startswith("## ")] + [len(ls)]
    if len(cuts) < 3:
        sys.exit("fewer than 2 H2 sections; nothing to split")
    base = os.path.splitext(f)[0]
    secs = [(ls[a][3:].strip(), ls[a:b]) for a, b in zip(cuts, cuts[1:])]
    packs, cur, size = [], [], 0  # pack small adjacent sections up to ~5 KB per shard
    for t, body in secs:
        n = sum(len(x) + 1 for x in body)
        if cur and size + n > 5000:
            packs.append(cur); cur, size = [], 0
        cur.append((t, body)); size += n
    packs.append(cur)
    idx = ls[:cuts[0]] + ["", "Split into small files. Open only the shard you need:", ""]
    for n, pack in enumerate(packs, 1):
        slug = re.sub(r"[^a-z0-9]+", "-", pack[0][0].lower()).strip("-")[:40] or "part"
        rel = "%s/%02d-%s.md" % (os.path.basename(base), n, slug)
        titles = "; ".join(t for t, _ in pack)
        lines = [x for _, body in pack for x in body]
        idx.append("- [%s](%s): %s" % (os.path.basename(rel), rel, titles))
        print("%s%s  %d lines" % ("write " if apply else "plan  ", rel, len(lines)))
        if apply:
            os.makedirs(base, exist_ok=True)
            open(os.path.join(os.path.dirname(f), rel), "w").write(fix_links("\n".join(lines).rstrip()) + "\n")
    if apply:
        open(f, "w").write("\n".join(idx) + "\n")
    else:
        print("dry-run; add --apply (commit or back up first).")


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    {"scan": lambda: scan(), "index": lambda: index(a[1]), "get": lambda: get(a[1], a[2]),
     "split-md": lambda: split_md(a[1], "--apply" in a)}.get(a[0], lambda: sys.exit(__doc__))()
