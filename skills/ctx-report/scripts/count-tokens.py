import collections
import glob
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from dates import month_of, month_start, to_jst  # noqa: E402
from script_io import fail, require_month  # noqa: E402
from transcripts import entries, projects_dir, touched_since  # noqa: E402

WEIGHTS = {"input": 1, "write_5m": 1.25, "write_1h": 2, "read": 0.1, "output": 5}


def usage_of(path, seen, month=None):
    requests = {}
    custom = ai = ""
    place = ""
    branches = collections.Counter()
    first = None
    for entry in entries(path):
        kind = entry.get("type")
        if kind == "custom-title":
            custom = entry.get("customTitle") or custom
        if kind == "ai-title":
            ai = entry.get("aiTitle") or ai
        if entry.get("timestamp") and first is None:
            first = to_jst(entry["timestamp"])
            if month and month_of(entry["timestamp"]) != month:
                return None
        if entry.get("cwd") and not place:
            place = os.path.basename(entry["cwd"].split("/.claude/worktrees/")[0])
        if entry.get("gitBranch"):
            branches[entry["gitBranch"]] += 1
        if kind == "assistant":
            message = entry.get("message", {})
            usage = message.get("usage")
            key = entry.get("requestId") or message.get("id")
            if usage and key:
                requests[key] = usage
    total = {name: 0 for name in WEIGHTS}
    counted = 0
    for key, usage in requests.items():
        if key in seen:
            continue
        seen.add(key)
        counted += 1
        cache = usage.get("cache_creation") or {}
        written = usage.get("cache_creation_input_tokens", 0)
        hour = cache.get("ephemeral_1h_input_tokens", 0)
        total["input"] += usage.get("input_tokens", 0)
        total["write_1h"] += hour
        total["write_5m"] += written - hour
        total["read"] += usage.get("cache_read_input_tokens", 0)
        total["output"] += usage.get("output_tokens", 0)
    named = [name for name, _ in branches.most_common() if name != "HEAD"]
    branch = named[0] if named else ("HEAD" if branches else "")
    return {"requests": counted, "total": total, "title": custom or ai, "place": place, "branch": branch, "first": first}


def weighted(total):
    return sum(total[name] * weight for name, weight in WEIGHTS.items())


def man(value):
    return f"{value / 10000:,.0f}"


def main():
    month = require_month(sys.argv[1] if len(sys.argv) > 1 else None, "使い方: count-tokens.py <YYYY-MM> [件数]")
    if len(sys.argv) > 2 and not sys.argv[2].isdigit():
        fail("件数は数字で書く")

    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    projects = projects_dir()
    start = month_start(month)
    seen = set()

    rows = []
    for path in touched_since(os.path.join(projects, "*", "*.jsonl"), start):
        session = usage_of(path, seen, month)
        if not session or not session["requests"]:
            continue
        sub = 0
        for agent in glob.glob(os.path.join(path[: -len(".jsonl")], "subagents", "*.jsonl")):
            sub += weighted(usage_of(agent, seen)["total"])
        main_weight = weighted(session["total"])
        rows.append((main_weight + sub, sub, session))

    if not rows:
        fail(f"{month} の会話の記録が無い: {projects}")

    rows.sort(key=lambda row: row[0], reverse=True)
    everything = sum(row[0] for row in rows)

    print(f"# {month} の重い作業\n")
    print(f"会話は {len(rows)} 件、入力換算で合わせて {man(everything)} 万トークンである。上位 {min(limit, len(rows))} 件を並べる。\n")
    print("| 日付 | 場所 | 作業 | 要求 | 入力換算（万） | サブエージェント | 文脈の平均（万） | 出力（万） |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for weight, sub, session in rows[:limit]:
        total = session["total"]
        share = f"{sub / weight:.0%}" if weight else "0%"
        context = (total["input"] + total["write_5m"] + total["write_1h"] + total["read"]) / session["requests"]
        place = session["place"] + (f" @{session['branch']}" if session["branch"] else "")
        title = session["title"].replace("|", "／") or "（題なし）"
        print(
            f"| {session['first']:%m-%d} | {place.replace('|', '／')} | {title} | {session['requests']} | {man(weight)} | {share} "
            f"| {context / 10000:.1f} | {man(total['output'])} |"
        )


if __name__ == "__main__":
    main()
