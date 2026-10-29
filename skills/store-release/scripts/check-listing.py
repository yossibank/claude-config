import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from script_io import fail  # noqa: E402

LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "keywords.txt": 100,
    "promotional_text.txt": 170,
    "description.txt": 4000,
    "release_notes.txt": 4000,
    "support_url.txt": 255,
    "privacy_url.txt": 255,
}
OPTIONAL = {"promotional_text.txt", "release_notes.txt"}


def check_file(folder, name, limit):
    path = os.path.join(folder, name)
    if not os.path.exists(path):
        return None if name in OPTIONAL else f"NG {name} が無い"
    text = Path(path).read_text(encoding="utf-8").strip()
    count = len(text)
    if not text and name not in OPTIONAL:
        return f"NG {name} が空"
    if count > limit:
        return f"NG {name} が {count} 字（上限 {limit}）"
    if name.endswith("_url.txt") and not text.startswith("https://"):
        return f"NG {name} が https:// で始まらない"
    return f"OK {name} {count}/{limit}"


def check_keywords(text):
    words = text.strip().split(",")
    if any(w != w.strip() for w in words):
        yield "NG keywords.txt のカンマの前後に空白がある。字数の無駄になる"
    if "、" in text or "，" in text:
        yield "NG keywords.txt は半角のカンマで区切る"
    if text.strip() and any(not w.strip() for w in words):
        yield "NG keywords.txt に空の語がある"


def check_folder(folder):
    for name, limit in LIMITS.items():
        line = check_file(folder, name, limit)
        if line:
            yield line
    keywords = os.path.join(folder, "keywords.txt")
    if os.path.exists(keywords):
        yield from check_keywords(Path(keywords).read_text(encoding="utf-8"))


def report(lines):
    ok = True
    for line in lines:
        print(line)
        ok = ok and not line.startswith("NG")
    return ok


def main():
    if len(sys.argv) < 2:
        fail("使い方: check-listing.py <掲載情報のフォルダ>")

    ok = report(check_folder(sys.argv[1]))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
