import hashlib
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "lib"))

from hook_io import read_payload, run_hook  # noqa: E402
from hook_state import prepare_state, safe_name, state_folder  # noqa: E402

MIN_WORDS = 8
TAIL = 64 * 1024
EXCERPT = 50
STATE = state_folder("reply-japanese")
STALE = 7 * 24 * 60 * 60
FENCE = re.compile(r"```.*?(```|$)", re.S)
INLINE = re.compile(r"`[^`\n]*`")
URL = re.compile(r"https?://\S+")
WORD = re.compile(r"[A-Za-z]{2,}")
JAPANESE = re.compile(r"[぀-ヿ㐀-鿿ｦ-ﾟ]")


def last_reply(data):
    message = data.get("last_assistant_message")
    if isinstance(message, str):
        return "", message
    path = data.get("transcript_path")
    if not isinstance(path, str) or not os.path.isfile(path):
        return "", ""
    with open(path, "rb") as transcript:
        transcript.seek(0, os.SEEK_END)
        size = transcript.tell()
        transcript.seek(max(0, size - TAIL))
        lines = transcript.read().decode("utf-8", errors="replace").split("\n")
    if size > TAIL:
        lines = lines[1:]
    key, reply = "", ""
    for line in lines:
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if not isinstance(entry, dict):
            continue
        content = (entry.get("message") or {}).get("content")
        if entry.get("type") == "user" and is_prompt(content):
            key, reply = "", ""
        if entry.get("type") != "assistant" or not isinstance(content, list):
            continue
        texts = [block.get("text", "") for block in content if isinstance(block, dict) and block.get("type") == "text"]
        if any(text.strip() for text in texts):
            reply = "\n".join(texts)
            key = str(entry.get("uuid") or hashlib.sha256(reply.encode()).hexdigest())
    return key, reply


def is_prompt(content):
    if isinstance(content, str):
        return True
    return isinstance(content, list) and not any(isinstance(block, dict) and block.get("type") == "tool_result" for block in content)


def is_english(text):
    prose = URL.sub("", INLINE.sub("", FENCE.sub("", text)))
    words = len(WORD.findall(prose))
    return words >= MIN_WORDS and len(JAPANESE.findall(prose)) < words


def excerpt(text):
    line = next((line.strip() for line in text.splitlines() if line.strip()), "")
    return line if len(line) <= EXCERPT else line[:EXCERPT] + "…"


def is_flagged(data, key):
    prepare_state(STATE, STALE)
    path = Path(STATE, safe_name(f"{data.get('session_id', '')}-{data.get('agent_id', 'main')}"))
    seen = path.read_text(encoding="utf-8").split() if path.is_file() else []
    if key in seen:
        return True
    with path.open("a", encoding="utf-8") as state:
        state.write(key + "\n")
    return False


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "stop"
    data = read_payload()
    if data is None or data.get("stop_hook_active"):
        return
    key, reply = last_reply(data)
    if not is_english(reply):
        return
    if mode == "pre":
        if not key or data.get("agent_id") or is_flagged(data, key):
            return
        print(
            f"「{excerpt(reply)}」が英語になっている。この判定は一歩遅れて、前に書いた一言を見ている。"
            "途中経過も日本語で書く決まりなので、この道具は止めた。日本語に戻したら、同じ道具をそのまま呼び直してよい。",
            file=sys.stderr,
        )
        sys.exit(2)
    print(
        "最後の返事が英語になっている。報告・質問・途中経過は日本語で書く決まりなので、同じ中身を日本語で書き直す。",
        file=sys.stderr,
    )
    sys.exit(2)


if __name__ == "__main__":
    run_hook("reply-require-japanese", main)
