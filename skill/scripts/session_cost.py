#!/usr/bin/env python3
"""Parse a Claude Code transcript (JSONL) into cost drivers. Tolerant: unknown shapes give n/a."""
import json, sys, collections


def _size(c):
    if isinstance(c, str):
        return len(c)
    if isinstance(c, list):
        return sum(_size(x.get("text", x.get("content", ""))) if isinstance(x, dict) else _size(x) for x in c)
    return 0


def compute(path):
    usage, models, calls, owners = {}, [], collections.Counter(), {}
    res = collections.Counter()
    results, reads = [], collections.Counter()
    users = side = compact = 0
    for line in open(path, errors="replace"):
        try:
            o = json.loads(line)
        except ValueError:
            continue
        t, m = o.get("type"), o.get("message")
        if o.get("isSidechain"):
            side += 1
        if t == "system" and "compact" in str(o.get("subtype", "")):
            compact += 1
        if not isinstance(m, dict):
            continue
        if t == "user" and isinstance(m.get("content"), str):
            users += 1
        if t == "assistant":
            u = m.get("usage")
            mid = m.get("id") or o.get("uuid")
            if isinstance(u, dict) and mid:
                usage[mid] = u
            if m.get("model") and (not models or models[-1] != m["model"]):
                models.append(m["model"])
            for b in m.get("content") or []:
                if isinstance(b, dict) and b.get("type") == "tool_use":
                    n, i = b.get("name", "?"), b.get("input") or {}
                    calls[n] += 1
                    owners[b.get("id")] = (n, i.get("file_path") or i.get("command", "")[:60] or i.get("pattern", ""))
                    if n == "Read" and not i.get("limit") and not i.get("offset"):
                        reads[i.get("file_path", "?")] += 1
        if t == "user" and isinstance(m.get("content"), list):
            for b in m["content"]:
                if isinstance(b, dict) and b.get("type") == "tool_result":
                    n, tgt = owners.get(b.get("tool_use_id"), ("?", ""))
                    sz = _size(b.get("content"))
                    res[n] += sz
                    results.append((sz, n, str(tgt)))
    side_in = lambda u: sum(int(u.get(k) or 0) for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
    ins = [side_in(u) for u in usage.values()]
    first = side_in(next(iter(usage.values()))) if usage else None
    mcp = {k: v for k, v in res.items() if k.startswith("mcp__")}
    cw = sum(int(u.get("cache_creation_input_tokens") or 0) for u in usage.values())
    cr = sum(int(u.get("cache_read_input_tokens") or 0) for u in usage.values())
    ni = sum(int(u.get("input_tokens") or 0) for u in usage.values())
    return {
        "cache_hit": round(100 * cr / (cr + cw + ni)) if (cr + cw + ni) else None,
        "requests": len(usage), "user_turns": users, "models": models,
        "input_new": sum(int(u.get("input_tokens") or 0) for u in usage.values()),
        "cache_write": sum(int(u.get("cache_creation_input_tokens") or 0) for u in usage.values()),
        "cache_read": sum(int(u.get("cache_read_input_tokens") or 0) for u in usage.values()),
        "output": sum(int(u.get("output_tokens") or 0) for u in usage.values()),
        "peak_context": max(ins) if ins else None, "fixed_overhead": first,
        "tool_calls": dict(calls.most_common(8)), "tool_result_chars": sum(res.values()),
        "top_results": sorted(results, reverse=True)[:5], "result_by_tool": dict(res.most_common(6)),
        "repeated_full_reads": {k: v for k, v in reads.items() if v >= 2},
        "mcp_calls": sum(v for k, v in calls.items() if k.startswith("mcp__")),
        "mcp_result_chars": sum(mcp.values()), "sidechain_lines": side, "compactions": compact,
    }


if __name__ == "__main__":
    print(json.dumps(compute(sys.argv[1]), indent=1, default=str))
