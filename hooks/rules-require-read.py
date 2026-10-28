import calendar
import json
import os
import re
import sys
import tempfile
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import git_root, read_payload, remove_stale, safe_name, tool_input  # noqa: E402

RULES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "rules")
STATE = os.path.join(tempfile.gettempdir(), "claude-rules-read")
EDIT_TOOLS = ("Edit", "Write", "MultiEdit")
STALE = 7 * 24 * 60 * 60
TAIL_LIMIT = 32_000_000


def to_regex(pattern):
    out = ""
    i = 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pattern[i] == "*":
            out += "[^/]*"
            i += 1
        elif pattern[i] == "{" and "}" in pattern[i:]:
            end = pattern.index("}", i)
            out += "(?:" + "|".join(map(re.escape, pattern[i + 1 : end].split(","))) + ")"
            i = end + 1
        else:
            out += re.escape(pattern[i])
            i += 1
    return re.compile(out + "$")


def rule_paths(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    if not lines or lines[0] != "---":
        return []
    patterns = []
    for line in lines[1:]:
        if line == "---":
            break
        match = re.match(r'^\s*-\s*"?([^"]+)"?\s*$', line)
        if match:
            patterns.append(to_regex(match.group(1)))
    return patterns


def relative(path):
    root = git_root(path)
    return os.path.relpath(path, root) if root else None


def matching_rules(path):
    target = relative(path)
    found = []
    if target is None:
        return found
    for name in sorted(os.listdir(RULES)):
        if name.endswith(".md") and any(p.match(target) for p in rule_paths(os.path.join(RULES, name))):
            found.append(name)
    return found


def state_dir(data):
    return os.path.join(STATE, safe_name(f"{data.get('session_id', '')}-{data.get('agent_id', 'main')}"))


def read_time(data, name):
    try:
        return os.path.getmtime(os.path.join(state_dir(data), name))
    except OSError:
        return 0.0


def is_rule(path):
    real = os.path.realpath(path)
    return os.path.dirname(real) == os.path.realpath(RULES) or path.startswith(os.path.expanduser("~/.claude/rules/"))


def tail_after_compaction(transcript, chunk=4_000_000):
    with open(transcript, "rb") as file:
        file.seek(0, os.SEEK_END)
        position = file.tell()
        data = b""
        while position > 0 and len(data) < TAIL_LIMIT:
            step = min(chunk, position)
            position -= step
            file.seek(position)
            data = file.read(step) + data
            index = data.rfind(b'"compact_boundary"')
            if index >= 0:
                return data[data.rfind(b"\n", 0, index) + 1 :].decode("utf-8", "ignore").splitlines()
    return data.decode("utf-8", "ignore").splitlines()


def scan(transcript):
    compacted = 0.0
    loaded = set()
    if not transcript or not os.path.isfile(transcript):
        return compacted, loaded
    for line in tail_after_compaction(transcript):
        if '"compact_boundary"' in line:
            try:
                stamp = json.loads(line).get("timestamp", "")
                compacted = max(compacted, calendar.timegm(time.strptime(stamp[:19], "%Y-%m-%dT%H:%M:%S")))
            except (ValueError, TypeError):
                pass
            loaded = set()
        elif '"instructions"' in line and "/rules/" in line:
            try:
                files = json.loads(line).get("attachment", {}).get("files") or []
            except ValueError:
                continue
            loaded |= {os.path.basename(str(item.get("path", ""))) for item in files if is_rule(str(item.get("path", "")))}
    return compacted, loaded


def record_read(data, path):
    if not is_rule(path):
        return
    remove_stale(STATE, STALE)
    os.makedirs(state_dir(data), exist_ok=True)
    marker = os.path.join(state_dir(data), os.path.basename(path))
    with open(marker, "a"):
        os.utime(marker)


def check_edit(data, path):
    rules = matching_rules(path)
    if not rules:
        return
    transcript = data.get("transcript_path", "")
    compacted, loaded = scan(transcript)
    missing = [name for name in rules if read_time(data, name) <= compacted and name not in loaded]
    if missing:
        print(
            "この編集に当たる決まりを、この会話でまだ読んでいない。"
            "次を Read で読んでから、同じ編集をやり直す: " + "、".join(os.path.join(RULES, name) for name in missing),
            file=sys.stderr,
        )
        sys.exit(2)


def main():
    if os.environ.get("CLAUDE_RULES_GUARD") == "off":
        return
    data = read_payload()
    if data is None:
        return
    path = tool_input(data).get("file_path", "")
    if not path:
        return
    if data.get("tool_name") == "Read":
        record_read(data, path)
    elif data.get("tool_name") in EDIT_TOOLS:
        check_edit(data, path)


if __name__ == "__main__":
    main()
