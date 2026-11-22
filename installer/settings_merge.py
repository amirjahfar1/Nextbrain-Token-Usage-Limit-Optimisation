#!/usr/bin/env python3
"""Additive merge of settings.snippet.json into .claude/settings.json.
Usage: settings_merge.py <project> merge|remove [--dry-run] [--events=PreToolUse,...]
Never edits other keys, keeps the file's indent and non-ASCII text, writes only when something changed, and
records exactly what it added (installed.json) so remove takes out only that: single hook items, never a whole
matcher group, and never a rule the project already had. Aborts, writing nothing, on invalid or odd settings."""
import hashlib, json, os, re, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import state

MARK = "token-optimisation/hooks/"
here = os.path.dirname(os.path.abspath(__file__))
proj, mode, dry = os.path.abspath(sys.argv[1]), sys.argv[2], "--dry-run" in sys.argv
path = os.path.join(proj, ".claude", "settings.json")
snip = json.load(open(os.path.join(here, "settings.snippet.json")))
only = next((a.split("=", 1)[1].split(",") for a in sys.argv if a.startswith("--events=")), None)
if only is not None and only == ["none"]:
    only = []

def die(msg):
    sys.exit("settings: " + msg + " Not touching it. Merge installer/settings.snippet.json by hand.")

raw = open(path, "rb").read() if os.path.exists(path) else None
if raw is None:
    cur = {}
else:
    if raw.startswith(b"\xef\xbb\xbf") or not raw.strip():
        die("settings.json is empty or starts with a byte-order mark.")
    try:
        cur = json.loads(raw.decode("utf-8"))
    except ValueError:
        die("settings.json is not valid JSON (comments, trailing commas or similar).")
if not isinstance(cur, dict):
    die("settings.json is not a JSON object.")
perm, hooks = cur.get("permissions"), cur.get("hooks")
if perm is not None and (not isinstance(perm, dict) or not isinstance(perm.get("deny", []), list)):
    die("'permissions' (or its 'deny') has an unexpected type.")
if hooks is not None and (not isinstance(hooks, dict) or any(not isinstance(v, list) for v in hooks.values())):
    die("'hooks' has an unexpected type.")
indent = 2
m = re.search(rb"\n( +|\t)\"", raw or b"")
if m:
    indent = "\t" if m.group(1) == b"\t" else len(m.group(1))
orig = json.dumps(cur, sort_keys=True)
st = state.load(proj)
rec = st.get("settings", {"created": raw is None, "had_permissions": perm is not None, "had_deny": bool(perm and "deny" in perm),
                          "had_hooks": hooks is not None, "deny": [], "hooks": [], "migrated": []})
log = []
orig_copy = os.path.join(state.state_dir(proj), "originals", "settings.json")
sha_raw = hashlib.sha256(raw).hexdigest() if raw is not None else None

def script_of(cmd):
    mm = re.search(r"hooks/([a-z_]+\.py)", cmd)
    return mm.group(1) if mm else None

def hook_items(event):
    for g in (cur.get("hooks") or {}).get(event, []):
        for h in (g.get("hooks") or []) if isinstance(g, dict) else []:
            if isinstance(h, dict):
                yield g, h

if mode == "remove" and raw is not None and rec.get("written") == sha_raw and os.path.exists(orig_copy):
    print("settings: restored the original file byte for byte")
    if not dry:
        state.backup(proj, path, "settings.json")
        shutil.copyfile(orig_copy, path)
        os.remove(orig_copy)
        state.rmdir_if_empty(os.path.dirname(orig_copy))
        st.pop("settings", None)
        state.save(proj, st) if st else state.drop(proj)
    sys.exit(0)
if mode == "merge":
    deny = cur.setdefault("permissions", {}).setdefault("deny", [])
    legacy_first = not st.get("settings") and raw is not None and MARK.encode() in raw  # an install from before installed.json added these
    for r in snip["permissions"]["deny"]:
        if legacy_first and r in deny and r not in rec["deny"]:
            rec["deny"].append(r)
        if r not in deny and r not in rec["deny"]:
            deny.append(r); rec["deny"].append(r); log.append("deny " + r)
    for ev, entries in snip["hooks"].items():
        if only is not None and ev not in only:
            continue
        for e in entries:
            cmd, script = e["hooks"][0]["command"], script_of(e["hooks"][0]["command"])
            mine = [h for g, h in hook_items(ev) if script_of(str(h.get("command", ""))) == script and MARK in str(h.get("command", ""))]
            if mine:
                for h in mine:  # migrate an older command form in place; a project's own hooks never match MARK
                    if h.get("command") != cmd and str(h.get("command", "")).startswith("python3 "):
                        h["command"] = cmd; log.append("hook %s %s (command updated)" % (ev, script))
                continue
            if [ev, script] in rec["hooks"]:  # we added it once and the owner removed it: respect that
                continue
            cur.setdefault("hooks", {}).setdefault(ev, []).append(e)
            rec["hooks"].append([ev, script]); log.append("hook %s %s" % (ev, script))
else:
    legacy = not st.get("settings")
    for ev in list((cur.get("hooks") or {})):
        groups = []
        for g in cur["hooks"][ev]:
            items = g.get("hooks") if isinstance(g, dict) else None
            if isinstance(items, list):
                keep = [h for h in items if not (isinstance(h, dict) and MARK in str(h.get("command", "")) and True)]
                if len(keep) != len(items):
                    log.append("hook %s removed (%d)" % (ev, len(items) - len(keep)))
                if not keep and items:
                    continue
                g = dict(g, hooks=keep)
            groups.append(g)
        if groups:
            cur["hooks"][ev] = groups
        else:
            del cur["hooks"][ev]
    if isinstance(cur.get("permissions"), dict):
        d = cur["permissions"].get("deny", [])
        gone = [r for r in d if r in (snip["permissions"]["deny"] if legacy else rec["deny"])]
        if gone:
            cur["permissions"]["deny"] = [r for r in d if r not in gone]; log += ["deny removed " + r for r in gone]
        if not cur["permissions"].get("deny"):
            cur["permissions"].pop("deny", None)
        if not cur["permissions"]:
            del cur["permissions"]
    if "hooks" in cur and not cur["hooks"]:
        del cur["hooks"]

print("\n".join(log) or "settings: nothing to change")
changed = json.dumps(cur, sort_keys=True) != orig
if changed and not dry:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if raw is not None:
        state.backup(proj, path, "settings.json")
    if mode == "remove" and rec.get("created") and not cur:
        os.remove(path)
        state.rmdir_if_empty(os.path.dirname(path))
    else:
        out = json.dumps(cur, indent=indent, ensure_ascii=False) + "\n"
        if mode == "merge" and raw is not None and not os.path.exists(orig_copy) and MARK.encode() not in raw:  # never keep a file that already holds our entries as "the original"
            os.makedirs(os.path.dirname(orig_copy), exist_ok=True)
            open(orig_copy, "wb").write(raw)
        open(path, "w", encoding="utf-8").write(out)
        if mode == "merge":
            rec["written"] = hashlib.sha256(out.encode("utf-8")).hexdigest()
if not dry:
    if mode == "merge":
        st["settings"] = rec
        state.save(proj, st)
    elif "settings" in st:
        del st["settings"]
        state.save(proj, st) if st else state.drop(proj)
