#!/usr/bin/env python3
"""Token Meter report (stdlib only).
Usage: report.py [today|7d|30d|all] [--json] [--quick] [--md-out FILE|auto]
Reads the chat transcripts (<config>/projects/*/*.jsonl), the mods savings ledger (<config>/mods-logs/savings.jsonl)
and, per project, .claude/token-optimisation/guard.log. Costs are list-price estimates, not a bill.
--quick skips the before/after benefit analysis (it reuses the last saved one)."""
import collections, datetime as dt, glob, json, os, sys, time

CFG = os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR", "").strip() or "~/.claude")
OUT = os.path.join(CFG, "mods-logs", "token-meter")
M = 1e-6
MIN_REQ = 20  # requests needed on each side before a before/after comparison is shown


def price(model, prompt=0):
    """(input, output) USD per token, the same list prices as the savings-proof mod; None when unknown."""
    m = (model or "").lower()
    if "fable" in m or "mythos" in m: return 10 * M, 50 * M
    if "opus-5-5" in m or "opus-5.5" in m: return 4 * M, 20 * M
    if "opus-5" in m: return 5 * M, 25 * M
    if "sonnet-5" in m: return 2 * M, 10 * M
    if "haiku-5-5" in m or "haiku-5.5" in m:
        return (0.1 * M, 0.5 * M) if prompt <= 100_000 else (0.5 * M, 2.5 * M)
    if "haiku-4-5" in m or "haiku-4.5" in m: return 1 * M, 5 * M
    return None


def read_factor(model):
    m = (model or "").lower()
    if "fable" in m or "mythos" in m: return 0.025
    return 0.05 if ("opus-5-5" in m or "opus-5.5" in m) else 0.1


def start_of(rng):
    now = dt.datetime.now().astimezone()
    if rng == "today": return now.replace(hour=0, minute=0, second=0, microsecond=0)
    if rng == "7d": return now - dt.timedelta(days=7)
    if rng == "30d": return now - dt.timedelta(days=30)
    return dt.datetime.fromtimestamp(0).astimezone()


def parse_ts(s):
    try: t = dt.datetime.fromisoformat(str(s).replace("Z", "+00:00"))
    except ValueError: return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def n(u, k): return int(u.get(k) or 0)


def size(c):
    if isinstance(c, str): return len(c)
    if isinstance(c, list): return sum(size(x.get("text", x.get("content", ""))) if isinstance(x, dict) else size(x) for x in c)
    return 0


def transcripts():
    """(path, session id): the main chats, and each chat's subagent transcripts (projects/<p>/<session>/subagents/*.jsonl)."""
    base = os.path.join(CFG, "projects")
    for p in glob.glob(os.path.join(base, "*", "*.jsonl")):
        yield p, os.path.basename(p)[:-6]
    for p in glob.glob(os.path.join(base, "*", "*", "subagents", "*.jsonl")):
        yield p, os.path.basename(os.path.dirname(os.path.dirname(p)))


def scan(min_mtime=0):
    """One pass over the transcripts: requests, tool calls, tool-result sizes, compactions, first cwd per session.
    min_mtime skips files not touched since then (a quick run only needs recent files)."""
    reqs, tools, res, comp, first = {}, {}, [], [], {}
    for path, sid in transcripts():
        try:
            if min_mtime and os.path.getmtime(path) < min_mtime: continue
        except OSError: continue
        for line in open(path, errors="replace"):
            if '"usage"' not in line and '"tool_use"' not in line and '"tool_result"' not in line and "compact" not in line: continue
            try: o = json.loads(line)
            except ValueError: continue
            ts = parse_ts(o.get("timestamp"))
            if not ts: continue
            cwd = o.get("cwd")
            if cwd and (sid not in first or ts < first[sid][0]): first[sid] = (ts, cwd)
            t, m = o.get("type"), o.get("message")
            if t == "system" and "compact" in str(o.get("subtype", "")): comp.append((ts, sid)); continue
            if not isinstance(m, dict): continue
            if t == "user" and isinstance(m.get("content"), list):
                chars = sum(size(b.get("content")) for b in m["content"] if isinstance(b, dict) and b.get("type") == "tool_result")
                if chars: res.append((ts, sid, chars))
            if t != "assistant": continue
            for b in m.get("content") or []:
                if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("id"): tools[b["id"]] = (ts, b.get("name", "?"))
            u, key = m.get("usage"), m.get("id") or o.get("uuid")
            if isinstance(u, dict) and key and not str(m.get("model") or "").startswith("<"):
                reqs[key] = (ts, sid, m.get("model") or "", u, bool(o.get("isSidechain")))
    return reqs, tools, res, comp, first


def usage_cost(model, u):
    p = price(model, n(u, "input_tokens") + n(u, "cache_read_input_tokens") + n(u, "cache_creation_input_tokens"))
    if not p: return None
    cc = u.get("cache_creation") if isinstance(u.get("cache_creation"), dict) else {}
    w1, w5 = n(cc, "ephemeral_1h_input_tokens"), n(cc, "ephemeral_5m_input_tokens")
    if not (w1 or w5): w1 = n(u, "cache_creation_input_tokens")
    return (n(u, "input_tokens") * p[0] + w1 * 2 * p[0] + w5 * 1.25 * p[0]
            + n(u, "cache_read_input_tokens") * read_factor(model) * p[0] + n(u, "output_tokens") * p[1])


def ledger(start):
    path = os.path.join(CFG, "mods-logs", "savings.jsonl")
    rows, seen = {}, []
    try: text = open(path, errors="replace").read()
    except OSError: return []
    for raw in text.splitlines():
        try: o = json.loads(raw)
        except ValueError: continue
        if not isinstance(o, dict) or not isinstance(o.get("before"), (int, float)) or not isinstance(o.get("after"), (int, float)): continue
        ts = parse_ts(o.get("ts"))
        if not ts or ts < start: continue
        tid = o.get("tool_use_id")
        if tid:
            if tid in rows and o.get("measured") != "real": continue
            rows[tid] = o
        else: seen.append(o)
    return list(rows.values()) + seen


def savings(start, entered, out_tokens):
    by = collections.defaultdict(lambda: {"actions": 0, "saved": 0, "usd_saved": 0.0})
    s = {"actions": 0, "real": 0, "estimated": 0, "saved_in": 0, "saved_out": 0, "usd_saved": 0.0, "helper_usd": 0.0, "left_out": 0}
    for o in ledger(start):
        b, a = o["before"], o["after"]
        h = o.get("helper") if isinstance(o.get("helper"), dict) else None
        if h:
            p = price(h.get("model", ""))
            if p: s["helper_usd"] += (h.get("in") or 0) * p[0] + (h.get("out") or 0) * p[1]
        row = by[o.get("mod") or "unknown"]
        usd = o.get("cost_usd") if isinstance(o.get("cost_usd"), dict) else None
        if usd:
            v = float(usd.get("saved") or 0); s["usd_saved"] += v; row["usd_saved"] += v
            s["actions"] += 1; row["actions"] += 1
            s["real" if o.get("measured") == "real" else "estimated"] += 1
            continue
        if b > 500_000 or (b > 100_000 and a > 0 and b / a > 1000): s["left_out"] += 1; continue
        if b == a: continue
        d = b - a
        out = o.get("tokens") == "output" or bool(o.get("stably"))
        s["saved_out" if out else "saved_in"] += d
        s["actions"] += 1; row["actions"] += 1; row["saved"] += d
        s["real" if o.get("measured") == "real" else "estimated"] += 1
    s["by_mod"] = [dict(mod=k, **v) for k, v in sorted(by.items(), key=lambda kv: -kv[1]["saved"])]
    s["pct_in"] = round(100 * s["saved_in"] / (s["saved_in"] + entered), 1) if s["saved_in"] + entered else None
    s["pct_out"] = round(100 * s["saved_out"] / (s["saved_out"] + out_tokens), 1) if s["saved_out"] + out_tokens else None
    return s


# ---------- before / after: what the system and the mods change ----------

def system_root(cwd):
    """(project root, first install time) when the project has the token-optimisation system, else (None, None)."""
    d = cwd or ""
    for _ in range(8):
        base = os.path.join(d, ".agents", "skills", "token-optimisation")
        if os.path.isfile(os.path.join(base, "VERSION")):
            # INSTALLED_AT is written once by the installer and survives updates and git checkouts; the file's
            # creation or modification time is only the fallback for installs made before it existed.
            at = parse_ts(open(os.path.join(base, "INSTALLED_AT")).read().strip()) if os.path.isfile(os.path.join(base, "INSTALLED_AT")) else None
            if at: return d, at.timestamp()
            st = os.stat(os.path.join(base, "VERSION"))
            return d, getattr(st, "st_birthtime", st.st_mtime)
        p = os.path.dirname(d)
        if p == d: break
        d = p
    return None, None


def mods_since():
    try:
        d = json.load(open(os.path.join(CFG, "plugins", "installed_plugins.json")))["plugins"]
        ts = [parse_ts(e[0].get("installedAt")) for k, e in d.items() if k.endswith("@nextbrain-mods") and e]
        ts = [t for t in ts if t]
        return min(ts) if ts else None
    except (OSError, ValueError, KeyError, IndexError, TypeError): return None


def group(sessions):
    r = sum(s["requests"] for s in sessions)
    if not r: return {"sessions": len(sessions), "requests": 0}
    fresh, cr = sum(s["fresh"] for s in sessions), sum(s["cache_read"] for s in sessions)
    return {"sessions": len(sessions), "requests": r,
            "cost_per_request": round(sum(s["cost"] for s in sessions) / r, 4),
            "fresh_per_request": round(fresh / r),
            "tool_chars_per_request": round(sum(s["res"] for s in sessions) / r),
            "cache_hit": round(100 * cr / (fresh + cr)) if fresh + cr else None,
            "avg_peak_context": round(sum(s["peak"] for s in sessions) / len(sessions)),
            "compactions_per_session": round(sum(s["comp"] for s in sessions) / len(sessions), 2)}


def compare(before, after):
    """Change of each metric from before to after, plus an indicative saving; only once both sides have MIN_REQ requests."""
    enough = before.get("requests", 0) >= MIN_REQ and after.get("requests", 0) >= MIN_REQ
    c = {"enough": enough, "before": before, "after": after}
    if not enough: return c
    ch = lambda k: round(100 * (after[k] - before[k]) / before[k]) if before.get(k) else None
    c["change_pct"] = {k: ch(k) for k in ("cost_per_request", "fresh_per_request", "tool_chars_per_request", "avg_peak_context")}
    c["est_saved_usd"] = round((before["cost_per_request"] - after["cost_per_request"]) * after["requests"], 2)
    c["est_saved_tokens"] = round((before["fresh_per_request"] - after["fresh_per_request"]) * after["requests"])
    return c


def guard_stats(roots, start):
    flagged = denied = est = 0
    for root in roots:
        try: lines = open(os.path.join(root, ".claude", "token-optimisation", "guard.log"), errors="replace").read().splitlines()
        except OSError: continue
        for ln in lines:
            p = ln.split("\t")
            if len(p) < 4: continue
            try:
                if float(p[0]) < start.timestamp(): continue
            except ValueError: continue
            if p[1] == "deny": denied += 1
            flagged += 1
            try:
                if p[3] == "full": est += os.path.getsize(os.path.join(root, p[2])) // 4
            except OSError: pass
    return {"flagged": flagged, "denied": denied, "est_tokens_in_big_reads": est}


def benefit(reqs, res, comp, first, start):
    S = {}
    for ts, sid, model, u, sc in reqs.values():
        s = S.setdefault(sid, {"first": ts, "requests": 0, "cost": 0.0, "fresh": 0, "cache_read": 0, "peak": 0, "res": 0, "comp": 0})
        c = usage_cost(model, u)
        ctx = n(u, "input_tokens") + n(u, "cache_read_input_tokens") + n(u, "cache_creation_input_tokens")
        s["first"] = min(s["first"], ts); s["requests"] += 1; s["cost"] += c or 0
        s["fresh"] += n(u, "input_tokens") + n(u, "cache_creation_input_tokens"); s["cache_read"] += n(u, "cache_read_input_tokens"); s["peak"] = max(s["peak"], ctx)
    for ts, sid, chars in res:
        if sid in S: S[sid]["res"] += chars
    for ts, sid in comp:
        if sid in S: S[sid]["comp"] += 1
    mod_at = mods_since()
    g = {"before": [], "with": [], "never": []}; roots = {}; era = {"before": [], "after": []}
    for sid, s in S.items():
        root, at = system_root(first.get(sid, (None, ""))[1])
        if root: roots[root] = at
        g["never" if root is None else ("with" if s["first"].timestamp() >= at else "before")].append(s)
        if mod_at: era["after" if s["first"] >= mod_at else "before"].append(s)
    sysc = compare(group(g["before"]), group(g["with"]))
    sysc["never"] = group(g["never"]); sysc["projects"] = len(roots)
    modc = compare(group(era["before"]), group(era["after"]))
    modc["since"] = mod_at.astimezone().date().isoformat() if mod_at else None
    return {"system": sysc, "mods": modc, "guard": guard_stats(roots, start)}


def verdict(b):
    s = b["system"]
    if not s["projects"]: return "No project has the token system yet: install it (START-HERE) to start measuring."
    if not s["enough"]:
        return "Collecting data: need %d requests before and with the system (now %d before, %d with)." % (MIN_REQ, s["before"].get("requests", 0), s["after"].get("requests", 0))
    c = s["change_pct"]["cost_per_request"]
    if c is None: return "Not comparable yet: the sessions before the system have no priced requests."
    return "With the system a request costs %s%d%% (indicative); about $%.2f %s over %d requests." % (
        "-" if c < 0 else "+", abs(c), abs(s["est_saved_usd"]), "saved" if s["est_saved_usd"] >= 0 else "extra", s["after"]["requests"])


def build(rng, quick=False):
    start = start_of(rng)
    reqs_all, tools_all, res, comp, first = scan(start.timestamp() if quick and rng != "all" else 0)
    reqs = {k: v for k, v in reqs_all.items() if v[0] >= start}
    tools = {k: v[1] for k, v in tools_all.items() if v[0] >= start}
    t = collections.Counter(); cost = 0.0; unpriced = 0
    day = collections.defaultdict(collections.Counter); day_s = collections.defaultdict(set)
    mod = collections.defaultdict(collections.Counter)
    pr = collections.defaultdict(collections.Counter); pr_s = collections.defaultdict(set)
    sessions, side = set(), 0
    for ts, sid, model, u, sc in reqs.values():
        c = usage_cost(model, u)
        if c is None: unpriced += 1
        else: cost += c
        cwd = os.path.basename(first.get(sid, (None, ""))[1] or "") or "?"
        d = ts.astimezone().date().isoformat()
        fresh, cw, cr, o = n(u, "input_tokens"), n(u, "cache_creation_input_tokens"), n(u, "cache_read_input_tokens"), n(u, "output_tokens")
        for acc in (t, day[d], mod[model or "?"], pr[cwd]):
            acc["requests"] += 1; acc["fresh"] += fresh + cw; acc["cache_read"] += cr; acc["output"] += o; acc["cost_c"] += int(round((c or 0) * 1e6))
        sessions.add(sid); day_s[d].add(sid); pr_s[cwd].add(sid); side += sc
    tot_in = t["fresh"] + t["cache_read"]
    tc = collections.Counter(tools.values())
    r = {
        "range": rng, "from": (min(v[0] for v in reqs.values()) if rng == "all" and reqs else start).date().isoformat(), "to": dt.date.today().isoformat(), "generated": int(time.time()),
        "sessions": len(sessions), "requests": t["requests"], "subagent_requests": side,
        "tokens": {"fresh_input": t["fresh"], "cache_read": t["cache_read"], "output": t["output"], "total_input": tot_in},
        "cache_hit": round(100 * t["cache_read"] / tot_in) if tot_in else None,
        "cost_usd": round(cost, 2), "unpriced_requests": unpriced,
        "days": [{"date": d, "sessions": len(day_s[d]), "requests": v["requests"], "fresh": v["fresh"], "cache_read": v["cache_read"], "output": v["output"], "cost": round(v["cost_c"] / 1e6, 2)} for d, v in sorted(day.items())][-14:],
        "models": [{"model": k, "requests": v["requests"], "fresh": v["fresh"], "output": v["output"], "cost": round(v["cost_c"] / 1e6, 2)} for k, v in sorted(mod.items(), key=lambda kv: -kv[1]["cost_c"])][:6],
        "projects": [{"name": k, "sessions": len(pr_s[k]), "tokens": v["fresh"] + v["cache_read"] + v["output"]} for k, v in sorted(pr.items(), key=lambda kv: -(kv[1]["fresh"] + kv[1]["cache_read"]))][:6],
        "tools": [{"name": k, "n": v} for k, v in tc.most_common(8)],
        "savings": savings(start, t["fresh"], t["output"]),
    }
    cache = os.path.join(OUT, "benefit.json")
    if not quick:
        r["benefit"] = benefit(reqs_all, res, comp, first, start)
        r["benefit"]["verdict"] = verdict(r["benefit"])
        try: os.makedirs(OUT, exist_ok=True); json.dump(r["benefit"], open(cache, "w"))
        except OSError: pass
    else:
        try: r["benefit"] = json.load(open(cache))
        except (OSError, ValueError): r["benefit"] = None
    return r


def k(x):
    x = int(x)
    return f"{x/1e6:.1f}M" if x >= 1e6 else f"{x/1e3:.1f}k" if x >= 1e3 else str(x)


def markdown(r):
    s, tk = r["savings"], r["tokens"]
    pct = lambda v: "n/a" if v is None else f"{v}%"
    L = [f"# Token Meter report: {r['range']} ({r['from']} to {r['to']})", "",
         f"- Sessions: {r['sessions']} ({r['requests']} requests, {r['subagent_requests']} by subagents)",
         f"- Input: {k(tk['total_input'])} tokens ({k(tk['fresh_input'])} fresh, {k(tk['cache_read'])} read from cache). Cache hit {pct(r['cache_hit'])}",
         f"- Output: {k(tk['output'])} tokens", f"- Cost estimate: ${r['cost_usd']:.2f} at list prices" + (f" ({r['unpriced_requests']} requests of an unpriced model left out)" if r["unpriced_requests"] else ""), "",
         "## Is the system paying off? (all history, indicative)", ""]
    b = r.get("benefit")
    if b:
        L.append("**" + b["verdict"] + "**"); L.append("")
        sy = b["system"]
        if sy["enough"]:
            B, A = sy["before"], sy["after"]; c = sy["change_pct"]
            f = lambda v: "n/a" if v is None else f"{v:+d}%"
            L += ["| per request | before the system | with the system | change |", "|---|---|---|---|",
                  f"| cost | ${B['cost_per_request']:.3f} | ${A['cost_per_request']:.3f} | {f(c['cost_per_request'])} |",
                  f"| fresh input tokens | {k(B['fresh_per_request'])} | {k(A['fresh_per_request'])} | {f(c['fresh_per_request'])} |",
                  f"| tool output (chars) | {k(B['tool_chars_per_request'])} | {k(A['tool_chars_per_request'])} | {f(c['tool_chars_per_request'])} |",
                  f"| average peak context | {k(B['avg_peak_context'])} | {k(A['avg_peak_context'])} | {f(c['avg_peak_context'])} |",
                  f"| cache hit | {pct(B['cache_hit'])} | {pct(A['cache_hit'])} | |",
                  f"| compactions per session | {B['compactions_per_session']} | {A['compactions_per_session']} | |", "",
                  f"Indicative saving since the system went in: about ${sy['est_saved_usd']:.2f} and {k(sy['est_saved_tokens'])} fresh input tokens ({A['sessions']} sessions)."]
        else:
            L.append(f"Before the system: {sy['before'].get('requests', 0)} requests. With it: {sy['after'].get('requests', 0)} requests. Needs {MIN_REQ} each. Projects without the system: {sy['never'].get('sessions', 0)} sessions.")
        mo = b["mods"]
        if mo["since"]:
            L += ["", f"Mods installed {mo['since']}: " + (f"cost per request {mo['change_pct']['cost_per_request']:+d}% after them (all projects)." if mo["enough"] else f"collecting data (needs {MIN_REQ} requests on each side).")]
        g = b["guard"]
        if g["flagged"]: L += ["", f"Guard: {g['flagged']} big or generated file reads flagged ({g['denied']} blocked), about {k(g['est_tokens_in_big_reads'])} tokens of content."]
    else: L.append("Run the full report to compute this.")
    L += ["", "## Savings the mods measured (this period)", "",
          f"- Tokens kept out of context: {k(s['saved_in'])} input ({pct(s['pct_in'])} of what would have entered), {k(s['saved_out'])} output ({pct(s['pct_out'])})",
          f"- Actions counted: {s['actions']} ({s['real']} real, {s['estimated']} estimated)",
          f"- Model routing saved ${s['usd_saved']:.2f}; helper models cost ${s['helper_usd']:.2f}"]
    if s["by_mod"]: L += ["", "| mod | actions | tokens kept out | $ saved |", "|---|---|---|---|"] + [f"| {m['mod']} | {m['actions']} | {k(m['saved'])} | ${m['usd_saved']:.2f} |" for m in s["by_mod"]]
    L += ["", "## By day", "", "| day | sessions | requests | fresh in | cache read | out | $ |", "|---|---|---|---|---|---|---|"]
    L += [f"| {d['date']} | {d['sessions']} | {d['requests']} | {k(d['fresh'])} | {k(d['cache_read'])} | {k(d['output'])} | {d['cost']:.2f} |" for d in r["days"]]
    L += ["", "## By model", ""] + [f"- {m['model']}: {m['requests']} requests, {k(m['fresh'])} fresh in, {k(m['output'])} out, ${m['cost']:.2f}" for m in r["models"]]
    L += ["", "## By project", ""] + [f"- {p['name']}: {p['sessions']} sessions, {k(p['tokens'])} tokens" for p in r["projects"]]
    L += ["", "## Top tools", ""] + [f"- {t['name']} x{t['n']}" for t in r["tools"]]
    L += ["", "## How this is counted", "",
          "- Tokens and sessions come from the chat transcripts, once per request. Cost is a list-price estimate, not a bill.",
          "- Before/after compares sessions in a project before and after the system was installed there (the INSTALLED_AT date the installer writes once), per request. Tasks differ between sessions, so treat it as an indicator that firms up with more sessions, not as proof.",
          "- Measured savings count only what the mods log (before and after tokens of an action). Savings from rules that stop waste before it happens (reading discipline) are only visible in the before/after numbers.",
          "- Saved % = kept out / (kept out + fresh input that did enter). Dollar savings from the ledger come from model routing only."]
    return "\n".join(L) + "\n"


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if x in ("today", "7d", "30d", "all")]
    rng = a[0] if a else "7d"
    r = build(rng, quick="--quick" in sys.argv)
    if "--md-out" in sys.argv:
        p = sys.argv[sys.argv.index("--md-out") + 1]
        if p == "auto": p = os.path.join(OUT, "report-%s.md" % rng)
        os.makedirs(os.path.dirname(os.path.abspath(p)), exist_ok=True)
        open(p, "w").write(markdown(r))
        r["md_path"] = p
    print(json.dumps(r) if "--json" in sys.argv else markdown(r))
