import os
import sys

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

if len(sys.argv) < 2:
    sys.exit("使い方: listing-check.py <掲載情報のフォルダ>")

folder = sys.argv[1]
ok = True

for name, limit in LIMITS.items():
    path = os.path.join(folder, name)
    if not os.path.exists(path):
        if name not in OPTIONAL:
            print(f"NG {name} が無い")
            ok = False
        continue
    text = open(path, encoding="utf-8").read().strip()
    count = len(text)
    if not text and name not in OPTIONAL:
        print(f"NG {name} が空")
        ok = False
    elif count > limit:
        print(f"NG {name} が {count} 字（上限 {limit}）")
        ok = False
    elif name.endswith("_url.txt") and not text.startswith("https://"):
        print(f"NG {name} が https:// で始まらない")
        ok = False
    else:
        print(f"OK {name} {count}/{limit}")

keywords = os.path.join(folder, "keywords.txt")
if os.path.exists(keywords):
    words = [w for w in open(keywords, encoding="utf-8").read().strip().split(",")]
    if any(w != w.strip() for w in words):
        print("NG keywords.txt のカンマの前後に空白がある。字数の無駄になる")
        ok = False
    text = open(keywords, encoding="utf-8").read()
    if "、" in text or "，" in text:
        print("NG keywords.txt は半角のカンマで区切る")
        ok = False
    if text.strip() and any(not w.strip() for w in words):
        print("NG keywords.txt に空の語がある")
        ok = False

sys.exit(0 if ok else 1)
