import calendar
import json
import os
import re
import subprocess
import sys
import tempfile
import time

RULES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "rules")
STATE = os.path.join(tempfile.gettempdir(), "claude-rules-read")
EDIT_TOOLS = ("Edit", "Write", "MultiEdit")


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
        elif pattern[i] == "{":
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
    result = subprocess.run(
        ["git", "-C", os.path.dirname(path) or ".", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    root = result.stdout.strip()
    return os.path.relpath(path, root) if root else path.lstrip("/")


def matching_rules(path):
    target = relative(path)
    found = []
    for name in sorted(os.listdir(RULES)):
        if name.endswith(".md") and any(p.match(target) for p in rule_paths(os.path.join(RULES, name))):
            found.append(name)
    return found


def state_file(data):
    key = f"{data.get('session_id', '')}-{data.get('agent_id', 'main')}"
    return os.path.join(STATE, re.sub(r"[^A-Za-z0-9_-]", "_", key))


def read_state(data):
    try:
        return json.load(open(state_file(data)))
    except (OSError, ValueError):
        return {}


def scan(transcript):
    compacted = 0.0
    loaded = set()
    if not transcript or not os.path.isfile(transcript):
        return compacted, loaded
    for line in open(transcript, encoding="utf-8", errors="ignore"):
        if '"compact_boundary"' in line:
            try:
                stamp = json.loads(line).get("timestamp", "")
                compacted = max(compacted, calendar.timegm(time.strptime(stamp[:19], "%Y-%m-%dT%H:%M:%S")))
            except (ValueError, TypeError):
                continue
            loaded = set()
        elif '"instructions"' in line and "/rules/" in line:
            try:
                files = json.loads(line).get("attachment", {}).get("files") or []
            except ValueError:
                continue
            loaded |= {os.path.basename(str(item.get("path", ""))) for item in files if "/rules/" in str(item.get("path", ""))}
    return compacted, loaded


def record_read(data, path):
    if os.path.dirname(os.path.realpath(path)) != os.path.realpath(RULES):
        return
    state = read_state(data)
    state[os.path.basename(path)] = time.time()
    os.makedirs(STATE, exist_ok=True)
    with open(state_file(data), "w") as file:
        json.dump(state, file)


def check_edit(data, path):
    rules = matching_rules(path)
    if not rules:
        return
    transcript = data.get("transcript_path", "")
    state = read_state(data)
    compacted, loaded = scan(transcript)
    missing = [name for name in rules if state.get(name, 0) <= compacted and name not in loaded]
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
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    path = (data.get("tool_input") or {}).get("file_path", "")
    if not path:
        return
    if data.get("tool_name") == "Read":
        record_read(data, path)
    elif data.get("tool_name") in EDIT_TOOLS:
        check_edit(data, path)


if __name__ == "__main__":
    main()
