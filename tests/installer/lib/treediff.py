#!/usr/bin/env python3
"""treediff.py A B [ignore-prefix...]: compare two trees without following symlinks. Exit 1 on any difference."""
import hashlib, os, sys
def snap(root, ign):
    out = {}
    for d, ds, fs in os.walk(root):
        for n in ds + fs:
            p = os.path.join(d, n); rel = os.path.relpath(p, root)
            if rel.startswith(".git/") or rel == ".git" or any(rel == i or rel.startswith(i.rstrip("/") + "/") for i in ign):
                continue
            if os.path.islink(p): out[rel] = "L:" + os.readlink(p)
            elif os.path.isdir(p): out[rel] = "D"
            else: out[rel] = "F:" + hashlib.sha256(open(p, "rb").read()).hexdigest()
        ds[:] = [x for x in ds if not os.path.islink(os.path.join(d, x))]
    return out
a, b = snap(sys.argv[1], sys.argv[3:]), snap(sys.argv[2], sys.argv[3:])
bad = 0
for k in sorted(set(a) | set(b)):
    if k not in b: print("REMOVED", k); bad = 1
    elif k not in a: print("ADDED  ", k); bad = 1
    elif a[k] != b[k]: print("CHANGED", k); bad = 1
sys.exit(bad)
