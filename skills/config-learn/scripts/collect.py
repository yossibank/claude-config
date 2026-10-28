import collections
import functools
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from hook_stops import BASH_EDITED, PR_UNCHECKED, RULES_UNREAD  # noqa: E402
from transcripts import MONTH, entries, month_start, projects_dir, to_jst, touched_since  # noqa: E402

CUE = re.compile(
    r"ではなく|じゃなく|違う|ちがう|やめ|しないで|外して|戻して|消して|不要|いらない|要らない|"
    r"おかしい|揃えて|そろえて|統一|勝手に|聞いて|前も|毎回|何度も"
)
WIDTH = 120
APPS = os.path.expanduser("~/Applications")
WORKTREES = os.path.expanduser("~/.claude/worktrees/")
PREFIX = APPS.replace("/", "-") + "-"
GUARDS = {"rules": RULES_UNREAD, "bash": BASH_EDITED, "pr": PR_UNCHECKED}
EDITS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
HOOK_ERROR = re.compile(r"PreToolUse:\w+ hook error: ")
GIT_C = re.compile(r"\bgit\s+-C\s+(\S+)")


def fail(message):
    print(f"NG {message}")
    sys.exit(1)


def text_of(content):
    if isinstance(content, list):
        content = " ".join(part.get("text", "") for part in content if isinstance(part, dict) and part.get("type") == "text")
    return content if isinstance(content, str) else ""


@functools.cache
def repo_root(cwd):
    path = cwd
    while path.startswith(APPS + "/"):
        if os.path.exists(os.path.join(path, ".git")):
            return path
        path = os.path.dirname(path)
    return cwd


def place_of(entry):
    cwd = entry.get("cwd", "")
    if cwd.startswith(WORKTREES):
        return cwd[len(WORKTREES) :].split("/")[0]
    cwd = repo_root(cwd.split("/.claude/worktrees/")[0])
    return os.path.relpath(cwd, APPS).replace("/", "-") if cwd.startswith(APPS + "/") else ""


def clip(text):
    match = CUE.search(text)
    begin = max(0, match.start() - 40) if match else 0
    return ("…" if begin else "") + text[begin : begin + WIDTH]


def entries_of(path, month):
    for entry in entries(path):
        if not entry.get("timestamp"):
            continue
        when = to_jst(entry["timestamp"])
        if when.strftime("%Y-%m") == month:
            yield entry, when


@functools.cache
def repo_of(path):
    while path not in ("", "/"):
        marker = os.path.join(path, ".git")
        if os.path.isfile(marker):
            gitdir = open(marker, encoding="utf-8").read().removeprefix("gitdir:").strip()
            return os.path.basename(gitdir.split("/.git/worktrees/")[0])
        if os.path.isdir(marker):
            return os.path.basename(path)
        if os.path.dirname(path).rstrip("/") + "/" == WORKTREES:
            return os.path.basename(path)
        path = os.path.dirname(path)
    return ""


def target_of(part, cwd):
    tool_input = part.get("input") or {}
    if part.get("name") in EDITS:
        return repo_of(os.path.dirname(tool_input.get("file_path") or tool_input.get("notebook_path") or ""))
    other = GIT_C.search(tool_input.get("command", "")) if part.get("name") == "Bash" else None
    return repo_of(os.path.expanduser(other.group(1)) if other else cwd)


def guard_of(text):
    return next((name for name, mark in GUARDS.items() if mark in text), "")


def parts_of(entry):
    content = (entry.get("message") or {}).get("content")
    return [part for part in content if isinstance(part, dict)] if isinstance(content, list) else []


def record_targets(entry, parts, tally):
    if entry.get("type") != "assistant":
        return
    for part in parts:
        if part.get("type") != "tool_use" or part.get("id") in tally["targets"]:
            continue
        place = target_of(part, entry.get("cwd", ""))
        tally["targets"][part.get("id")] = place
        if place and part.get("name") in EDITS:
            tally["stats"][place]["edits"] += 1


def blocks_of(entry, parts):
    blocks = []
    for part in parts:
        text = part.get("content") if part.get("type") == "tool_result" and part.get("is_error") else ""
        if isinstance(text, str) and HOOK_ERROR.match(text):
            blocks.append((part.get("tool_use_id"), guard_of(text)))
    attachment = entry.get("attachment") or {}
    if attachment.get("type") == "hook_blocking_error":
        blocks.append((attachment.get("toolUseID"), guard_of(json.dumps(attachment.get("blockingError"), ensure_ascii=False))))
    return blocks


def count_blocks(entry, blocks, tally):
    cwd = entry.get("cwd", "")
    for tool_use_id, name in blocks:
        key = (tool_use_id, name)
        if not name or key in tally["blocked"]:
            continue
        tally["blocked"].add(key)
        place = tally["targets"].get(tool_use_id) or repo_of(cwd)
        if place:
            tally["stats"][place][name] += 1


def count_broken(entry, tally):
    cwd = entry.get("cwd", "")
    attachment = entry.get("attachment") or {}
    if attachment.get("type") == "hook_non_blocking_error" and os.path.isdir(cwd):
        stderr = attachment.get("stderr", "").replace("Failed with non-blocking status code:", "").strip()
        first = stderr.splitlines()[0] if stderr else ""
        tally["broken"][(attachment.get("hookName", ""), first if len(first) <= 100 else "…" + first[-100:])] += 1


def print_memories(projects):
    print("## feedback のメモリ\n")
    memories = 0
    for path in sorted(glob.glob(os.path.join(projects, "*", "memory", "*.md"))):
        text = open(path, encoding="utf-8", errors="ignore").read()
        if not re.search(r"^\s*type:\s*feedback\s*$", text, re.M):
            continue
        description = re.search(r"^description:\s*(.+)$", text, re.M)
        project = os.path.basename(os.path.dirname(os.path.dirname(path)))
        if not project.startswith(PREFIX):
            continue
        repo = project[len(PREFIX) :].split("--claude-worktrees-")[0]
        memories += 1
        print(f"- {repo}／{os.path.basename(path)}：{description.group(1).strip() if description else ''}")
    if not memories:
        print("なし")


def correction_of(entry):
    if entry.get("type") != "user" or entry.get("isSidechain"):
        return ""
    text = text_of(entry.get("message", {}).get("content"))
    if not text or text.lstrip().startswith("<") or len(text) > 400 or not CUE.search(text):
        return ""
    return " ".join(text.split())


def print_guards(stats, broken):
    print("\n## 決まりの効き目\n")
    print("フックが止めた回数。決まりがあるのに止まる回数が多いものは、決まりが読まれずに作業が進んでいる。\n")
    rows = [(place, row) for place, row in sorted(stats.items()) if row["edits"] or any(row[name] for name in GUARDS)]
    if rows:
        print("| 場所 | 編集 | 決まりを読まずに編集 | Bash で書き換え | 確認の前の push・PR |")
        print("| --- | --- | --- | --- | --- |")
        for place, row in rows:
            print(f"| {place} | {row['edits']} | {row['rules']} | {row['bash']} | {row['pr']} |")
    else:
        print("なし")
    print("\n### 動かなかったフック\n")
    if broken:
        for (hook, stderr), count in broken.most_common(5):
            print(f"- {hook}（{count} 回）：{stderr}")
    else:
        print("なし")


def main():
    if len(sys.argv) < 2 or not MONTH.fullmatch(sys.argv[1]):
        fail("使い方: collect.py <YYYY-MM>")

    month = sys.argv[1]
    projects = projects_dir()
    start = month_start(month)

    print(f"# {month} の手直しの材料\n")
    print_memories(projects)

    print("\n## 手直しの言葉を含む人の文\n")
    seen = set()
    found = 0
    tally = {
        "stats": collections.defaultdict(collections.Counter),
        "broken": collections.Counter(),
        "targets": {},
        "blocked": set(),
    }
    sessions = touched_since(os.path.join(projects, "*", "*.jsonl"), start)
    subagents = touched_since(os.path.join(projects, "*", "*", "subagents", "*.jsonl"), start)
    for path in sessions + subagents:
        for entry, when in entries_of(path, month):
            parts = parts_of(entry)
            record_targets(entry, parts, tally)
            count_blocks(entry, blocks_of(entry, parts), tally)
            count_broken(entry, tally)
            place = place_of(entry)
            flat = correction_of(entry) if place and "/subagents/" not in path else ""
            if not flat or flat in seen:
                continue
            seen.add(flat)
            found += 1
            print(f"- {when:%m-%d} {place}：{clip(flat)}")
    if not found:
        print("なし")

    print_guards(tally["stats"], tally["broken"])


if __name__ == "__main__":
    main()
