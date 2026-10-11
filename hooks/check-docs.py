import json
import os
import re
import sys

JA = r"々぀-ヺー-ヿ一-鿿"
README_TAGS = {"img", "picture", "source", "table", "thead", "tbody", "tr", "th", "td"}
LIMIT = 60

COUNT = re.compile(r"次の\s*[0-9０-９]+\s*(つ|段|個|点|項目)")
TAG = re.compile(r"<(/?)([A-Za-z][A-Za-z0-9]*)")
BOLD = re.compile(r"\*\*[^*\n]+?\*\*")
ITALIC = re.compile(r"(?<![A-Za-z0-9*])\*(?=\S)[^*\n]+?(?<=\S)\*(?![A-Za-z0-9*])|(?<![A-Za-z0-9_])_(?=\S)[^_\n]+?(?<=\S)_(?![A-Za-z0-9_])")
SPACE = re.compile(rf"[{JA}][A-Za-z0-9]|[A-Za-z0-9][{JA}]")
HAS_JA = re.compile(rf"[{JA}]")


def strip(line):
    line = re.sub(r"`[^`]*`", "", line)
    line = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", line)
    line = re.sub(r"<https?://[^>]*>", "", line)
    line = re.sub(r"https?://\S+", "", line)
    return re.sub(r"<!--.*?-->", "", line)


def check(path):
    readme = os.path.basename(path).lower() == "readme.md"
    lines = open(path, encoding="utf-8").read().split("\n")
    found = []
    start = 0
    if lines and lines[0] == "---":
        end = next((i for i in range(1, len(lines)) if lines[i] == "---"), 0)
        start = end + 1
    fence = False
    for number, raw in enumerate(lines[start:], start + 1):
        if raw.lstrip().startswith(("```", "~~~")):
            fence = not fence
            continue
        if fence:
            continue
        text = strip(raw)
        if COUNT.search(re.sub(r"「[^」]*」", "", text)):
            found.append((number, "一覧の前置きに項目の数を書かない"))
        for closing, name in TAG.findall(text):
            if not (readme and name.lower() in README_TAGS):
                found.append((number, f"使ってよい HTML ではない（<{closing}{name}>）"))
                break
        if ITALIC.search(BOLD.sub("", text)):
            found.append((number, "斜体を使わない"))
        if SPACE.search(text):
            found.append((number, "日本語と英数字の間に半角スペースを入れる"))
        body = text.strip()
        if body.startswith(("|", "#")) or "。" not in body:
            continue
        body = re.sub(r"<[^>]*>", "", body)
        body = re.sub(r"^(>\s*)?([-*]|\d+\.)?\s*", "", body).replace("**", "")
        for sentence in body.split("。"):
            if HAS_JA.search(sentence) and len(sentence) + 1 > LIMIT:
                found.append((number, f"一文が {LIMIT} 字を超えている（{len(sentence) + 1} 字）"))
    return found


def main():
    if len(sys.argv) > 1:
        paths = sys.argv[1:]
    else:
        data = json.load(sys.stdin)
        paths = [data.get("tool_input", {}).get("file_path", "")]
    report = []
    for path in paths:
        if path.endswith(".md") and os.path.isfile(path):
            report += [f"{path}:{n}: {m}" for n, m in check(path)]
    if report:
        print("文書の決まり（rules/docs.md）に合わない箇所がある。直す。", file=sys.stderr)
        print("\n".join(report), file=sys.stderr)
        sys.exit(2)


main()
