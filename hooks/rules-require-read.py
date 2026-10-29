import functools
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from dates import to_jst  # noqa: E402
from git import git_root  # noqa: E402
from hook_io import EDIT_TOOLS, read_payload, run_gate, tool_input  # noqa: E402
from hook_messages import RULES_UNREAD  # noqa: E402
from hook_state import prepare_state, safe_name, state_folder  # noqa: E402
from md_blocks import front_matter  # noqa: E402
from transcripts import parse_entry, tail_lines  # noqa: E402

RULES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "rules")
STATE = state_folder("rules-read")
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


@functools.cache
def rule_paths(path):
    fields = front_matter(Path(path).read_text(encoding="utf-8").split("\n")) or {}
    paths = fields.get("paths")
    return [to_regex(pattern) for pattern in paths] if isinstance(paths, list) else []


def relative(path, root=None):
    root = root or git_root(path)
    return os.path.relpath(path, root) if root else None


def matching_rules(path, root=None):
    target = relative(path, root)
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


def scan(transcript):
    compacted = 0.0
    loaded = set()
    if not transcript or not os.path.isfile(transcript):
        return compacted, loaded
    for line in tail_lines(transcript, TAIL_LIMIT, b'"compact_boundary"'):
        if '"compact_boundary"' in line:
            stamp = (parse_entry(line) or {}).get("timestamp", "")
            try:
                compacted = max(compacted, to_jst(stamp).timestamp())
            except (ValueError, TypeError, AttributeError):
                pass
            loaded = set()
        elif '"instructions"' in line and "/rules/" in line:
            entry = parse_entry(line)
            if entry is None:
                continue
            attachment = entry.get("attachment")
            files = attachment.get("files") if isinstance(attachment, dict) else None
            paths = [str(item.get("path", "")) for item in files if isinstance(item, dict)] if isinstance(files, list) else []
            loaded |= {os.path.basename(path) for path in paths if is_rule(path)}
    return compacted, loaded


def record_read(data, path):
    if not is_rule(path):
        return
    prepare_state(STATE, STALE)
    os.makedirs(state_dir(data), exist_ok=True)
    Path(state_dir(data), os.path.basename(path)).touch()


def check_edit(data, path):
    rules = matching_rules(path)
    if not rules:
        return
    transcript = data.get("transcript_path", "")
    compacted, loaded = scan(transcript)
    missing = [name for name in rules if read_time(data, name) <= compacted and name not in loaded]
    if missing:
        print(
            f"{RULES_UNREAD}。"
            "次を Read で読んでから、同じ編集をやり直す: " + "、".join(os.path.join(RULES, name) for name in missing),
            file=sys.stderr,
        )
        sys.exit(2)


def main():
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
    run_gate("rules-require-read", main)
