#!/usr/bin/env python3
"""Short expensive-session report. Usage: cost_report.py <transcript>|--last [--record STATE_DIR]"""
import glob, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from session_cost import compute

METRICS = ("peak_context", "tool_result_chars", "requests")


def history(state):
    rows = []
    try:
        for l in open(os.path.join(state, "sessions.tsv")):
            p = l.rstrip("\n").split("\t")
            if len(p) >= 6 and p[0] != "ts":
                rows.append([float(x) if x not in ("", "None") else 0 for x in p[2:5]])
    except (OSError, ValueError):
        pass
    return rows


def pct(vals, q):
    v = sorted(vals)
    return v[min(len(v) - 1, int(len(v) * q / 100))] if v else 0


def analyse(c, state, min_rows=10, q=75):
    flags, tips = [], []
    if c["repeated_full_reads"]:
        flags.append("repeated full reads"); tips.append("R4 never re-read; R2 read ranges")
    if c["compactions"]:
        flags.append("compaction happened"); tips.append("S2 checkpoint; S1 one slice per session")
    if len(c["models"]) > 1:
        flags.append("model switch"); tips.append("L3 do not switch model mid-slice")
    if c["top_results"] and c["top_results"][0][0] > 0 and c["mcp_result_chars"] >= c["tool_result_chars"] > 0:
        flags.append("MCP dominated results"); tips.append("M2 disable unused connectors")
    rows = history(state)
    status = "calibrating (%d/%d sessions)" % (len(rows), min_rows)
    if len(rows) >= min_rows:
        status = "p%d of own history" % q
        for i, name in enumerate(METRICS):
            lim = pct([r[i] for r in rows], q)
            if c[name] and c[name] > lim:
                flags.append("%s above own p%d" % (name, q)); tips.append("B3/R2 shrink reads" if i else "S1/S2 shorter sessions")
    return flags, list(dict.fromkeys(tips)), status


def report(c, flags, tips, status):
    out = ["Session cost: %s [%s]" % ("FLAGGED: " + ", ".join(flags) if flags else "ok", status),
           "requests %s, user turns %s, models %s" % (c["requests"], c["user_turns"], ",".join(c["models"]) or "n/a"),
           "peak context %s tok, fixed overhead %s tok" % (c["peak_context"], c["fixed_overhead"]),
           "cache write %s, cache read %s, new input %s, output %s" % (c["cache_write"], c["cache_read"], c["input_new"], c["output"]),
           "tool results %s chars (MCP %s), compactions %s" % (c["tool_result_chars"], c["mcp_result_chars"], c["compactions"]),
           "Top drivers:"]
    out += ["  %s chars  %s %s" % t for t in c["top_results"][:3]] or ["  n/a"]
    for k, v in list(c["repeated_full_reads"].items())[:2]:
        out.append("  full-read x%d: %s" % (v, k))
    out += ["Suggest: " + t for t in tips[:3]]
    return "\n".join(out[:15])


def main(argv):
    state = argv[argv.index("--record") + 1] if "--record" in argv else ".claude/token-optimisation"
    p = argv[1] if len(argv) > 1 else "--last"
    if p == "--last":
        base = os.path.expanduser("~/.claude/projects")
        fs = glob.glob(os.path.join(base, "*", "*.jsonl"))
        p = max(fs, key=os.path.getmtime) if fs else ""
    c = compute(p)
    flags, tips, status = analyse(c, state)
    if "--record" in argv:
        os.makedirs(state, exist_ok=True)
        f = os.path.join(state, "sessions.tsv")
        new = not os.path.exists(f)
        with open(f, "a") as fh:
            if new:
                fh.write("ts\tsession\tpeak_context\ttool_result_chars\trequests\tflags\n")
            fh.write("%d\t%s\t%s\t%s\t%s\t%s\n" % (time.time(), os.path.basename(p)[:36], c["peak_context"] or 0, c["tool_result_chars"], c["requests"], ";".join(flags)))
        if flags:
            with open(os.path.join(state, "pending-review"), "w") as fh:
                fh.write(p + "\n" + report(c, flags, tips, status) + "\n")
    print(report(c, flags, tips, status))


if __name__ == "__main__":
    main(sys.argv)
