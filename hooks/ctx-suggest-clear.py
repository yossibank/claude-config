import json
import os
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import read_payload, safe_name, tool_input  # noqa: E402
from transcripts import parse_entry, tail_lines  # noqa: E402

STEP = 200_000
TAIL = 4_000_000
STATE = os.path.join(tempfile.gettempdir(), "claude-suggest-clear")
KEYS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")
PR_URL = re.compile(r"https://github\.com/[^/\s]+/[^/\s]+/pull/\d+")
LONG_MESSAGE = "会話の文脈が約 {} 万トークンになりました。区切りのよいところで /ctx-handoff で引き継ぎメモを書き、/clear すると、使う量を抑えられます。"
PR_MESSAGE = "PR を作りました。この依頼が済んだら、/ctx-handoff で引き継ぎメモを書いてから /clear で区切ると、次の作業が軽くなります。"


def context_tokens(path):
    for line in reversed(tail_lines(path, TAIL)):
        if '"usage"' not in line:
            continue
        entry = parse_entry(line)
        if entry is None:
            continue
        message = entry.get("message")
        if entry.get("isSidechain") or not isinstance(message, dict):
            continue
        usage = message.get("usage")
        if isinstance(usage, dict):
            return sum(usage.get(key, 0) for key in KEYS)
    return 0


def notified_level(session):
    try:
        return int(Path(STATE, safe_name(session)).read_text())
    except (OSError, ValueError):
        return 0


def save_level(session, level):
    os.makedirs(STATE, exist_ok=True)
    Path(STATE, safe_name(session)).write_text(str(level))


def long_context(payload):
    path = payload.get("transcript_path")
    session = payload.get("session_id")
    if not path or not session or not os.path.isfile(path):
        return None
    tokens = context_tokens(path)
    level = tokens // STEP
    if level < 1 or level <= notified_level(session):
        return None
    save_level(session, level)
    return LONG_MESSAGE.format(tokens // 10_000)


def created_pr(payload):
    command = tool_input(payload).get("command", "")
    response = payload.get("tool_response")
    output = response.get("stdout", "") if isinstance(response, dict) else str(response or "")
    return "gh pr create" in command and "already exists" not in output and PR_URL.search(output) is not None


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "context"
    if mode not in ("context", "pr"):
        print(f"ctx-suggest-clear: 知らないモード「{mode}」。pr を渡すか、何も渡さない", file=sys.stderr)
        sys.exit(1)
    payload = read_payload()
    if payload is None:
        return
    if mode == "pr":
        message = PR_MESSAGE if created_pr(payload) else None
    else:
        message = long_context(payload)
    if message:
        print(json.dumps({"systemMessage": message}, ensure_ascii=False))


if __name__ == "__main__":
    main()
