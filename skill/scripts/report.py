#!/usr/bin/env python3
"""Cumulative usage report. Usage: report.py [--backfill N] [--state DIR]. Writes DIR/report.md and prints it."""
import collections, glob, json, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from session_cost import compute
from cost_report import analyse, make_row

arg = lambda k, d=None: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else d
state = arg("--state", ".claude/token-optimisation")
os.makedirs(state, exist_ok=True)
jf = os.path.join(state, "sessions.jsonl")
rows = [json.loads(l) for l in open(jf)] if os.path.exists(jf) else []
if arg("--backfill"):  # fill in sessions of this project that were never recorded
    have = {r["session"] for r in rows}
    base = os.path.expanduser("~/.claude/projects/" + re.sub(r"[^A-Za-z0-9]", "-", os.getcwd()))
    fs = sorted(glob.glob(base + "/*.jsonl"), key=os.path.getmtime)[-int(arg("--backfill")):]
    with open(jf, "a") as fh:
        for f in fs:
            if os.path.basename(f)[:36] in have:
                continue
            c = compute(f)
            if not c["requests"]:
                continue
            r = make_row(f, c, analyse(c, state)[0]); r["ts"] = int(os.path.getmtime(f))
            fh.write(json.dumps(r) + "\n"); rows.append(r)
n = len(rows)
out = ["# Token usage report (%s)" % time.strftime("%Y-%m-%d"), ""]
if not n:
    out.append("No sessions recorded yet. Hooks record each finished session; or run with --backfill 15.")
else:
    lat = rows[-1]
    out += ["Sessions: %d%s. Latest fixed overhead: %s tok. Latest peak context: %s tok." % (
        n, " (thresholds need 10)" if n < 10 else "", lat["fixed_overhead"], lat["peak_context"]), "",
        "## Last sessions", "", "| date | requests | peak ctx | tool results (chars) | MCP chars | flags |", "|---|---|---|---|---|---|"]
    for r in rows[-8:]:
        out.append("| %s | %s | %s | %s | %s | %s |" % (time.strftime("%m-%d %H:%M", time.localtime(r["ts"])), r["requests"],
                   r["peak_context"], r["tool_result_chars"], r["mcp_result_chars"], "; ".join(r["flags"]) or "-"))
    tool = collections.Counter(); item = collections.Counter(); hits = collections.Counter(); rep = collections.Counter()
    for r in rows:
        tool.update(r.get("by_tool", {}))
        for nme, tgt, z in r.get("top", []):
            item[(nme, tgt)] += z; hits[(nme, tgt)] += 1
        rep.update(r.get("repeated_reads", {}))
    tot = sum(tool.values()) or 1
    out += ["", "## What uses the most (tool results, all sessions)", ""]
    out += ["- %s: %d chars (%d%%)" % (k, v, 100 * v // tot) for k, v in tool.most_common(5)]
    out += ["", "## Biggest single results (repeat offenders first)", ""]
    out += ["- %s %s: %d chars in %d result(s)" % (k[0], k[1], v, hits[k]) for k, v in item.most_common(5)]
    if rep:
        out += ["", "## Files read in full twice or more", ""] + ["- %s (x%d)" % (k, v) for k, v in rep.most_common(5)]
    sug = []
    if rep: sug.append("R4 never re-read; R2 read ranges")
    if any(r["compactions"] for r in rows): sug.append("S2 checkpoint; S1 one slice per session")
    if any(len(r["models"]) > 1 for r in rows): sug.append("L3 do not switch model mid-slice")
    if sum(r["mcp_result_chars"] for r in rows) * 3 > tot: sug.append("M2/M5 trim connectors")
    if tool.get("Bash", 0) * 2 > tot: sug.append("R3 cap command output (head/tail)")
    out += ["", "## Suggestions (tip ids)", ""] + ["- " + x for x in sug[:4]] if sug else ["", "No structural problem found yet."]
open(os.path.join(state, "report.md"), "w").write("\n".join(out) + "\n")
print("\n".join(out))
