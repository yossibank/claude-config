import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "lib"))

from hook_io import read_payload, run_hook  # noqa: E402

MIN_WORDS = 8
FENCE = re.compile(r"```.*?(```|$)", re.S)
INLINE = re.compile(r"`[^`\n]*`")
URL = re.compile(r"https?://\S+")
WORD = re.compile(r"[A-Za-z]{2,}")
JAPANESE = re.compile(r"[぀-ヿ㐀-鿿ｦ-ﾟ]")


def last_reply(data):
    message = data.get("last_assistant_message")
    if isinstance(message, str):
        return message
    path = data.get("transcript_path")
    if not isinstance(path, str) or not os.path.isfile(path):
        return ""
    reply = ""
    with open(path, encoding="utf-8") as transcript:
        for line in transcript:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            if not isinstance(entry, dict):
                continue
            content = (entry.get("message") or {}).get("content")
            if entry.get("type") == "user" and is_prompt(content):
                reply = ""
            if entry.get("type") != "assistant" or not isinstance(content, list):
                continue
            texts = [block.get("text", "") for block in content if isinstance(block, dict) and block.get("type") == "text"]
            if any(text.strip() for text in texts):
                reply = "\n".join(texts)
    return reply


def is_prompt(content):
    if isinstance(content, str):
        return True
    return isinstance(content, list) and not any(isinstance(block, dict) and block.get("type") == "tool_result" for block in content)


def is_english(text):
    prose = URL.sub("", INLINE.sub("", FENCE.sub("", text)))
    words = len(WORD.findall(prose))
    return words >= MIN_WORDS and len(JAPANESE.findall(prose)) < words


def main():
    data = read_payload()
    if data is None or data.get("stop_hook_active"):
        return
    if not is_english(last_reply(data)):
        return
    print(
        "最後の返事が英語になっている。報告・質問・途中経過は日本語で書く決まりなので、同じ中身を日本語で書き直す。",
        file=sys.stderr,
    )
    sys.exit(2)


if __name__ == "__main__":
    run_hook("reply-require-japanese", main)
