import json
import os
import sys
import tempfile

STEP = 200_000
TAIL = 4_000_000
STATE = os.path.join(tempfile.gettempdir(), "claude-suggest-clear")
KEYS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")


def context_tokens(path):
    size = os.path.getsize(path)
    with open(path, "rb") as file:
        file.seek(max(size - TAIL, 0))
        lines = file.read().decode("utf-8", "ignore").splitlines()
    for line in reversed(lines):
        if '"usage"' not in line:
            continue
        try:
            entry = json.loads(line)
        except ValueError:
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
        return int(open(os.path.join(STATE, session)).read())
    except (OSError, ValueError):
        return 0


def save_level(session, level):
    os.makedirs(STATE, exist_ok=True)
    with open(os.path.join(STATE, session), "w") as file:
        file.write(str(level))


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
    return f"会話の文脈が約 {tokens // 10_000} 万トークンになりました。区切りのよいところで /ctx-handoff で引き継ぎメモを書き、/clear すると、使う量を抑えられます。"


PR_MESSAGE = "PR を作りました。この依頼が済んだら、/ctx-handoff で引き継ぎメモを書いてから /clear で区切ると、次の作業が軽くなります。"


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "context"
    payload = json.load(sys.stdin)
    message = PR_MESSAGE if mode == "pr" else long_context(payload)
    if message:
        print(json.dumps({"systemMessage": message}, ensure_ascii=False))


if __name__ == "__main__":
    main()
