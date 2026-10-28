import os
import re
import sys
from itertools import takewhile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))

from hook_io import read_payload, tool_input  # noqa: E402

JA = r"々぀-ヺー-ヿ一-鿿"
HTML_TAGS = {"img", "picture", "source", "table", "thead", "tbody", "tr", "th", "td", "details", "summary"}
LIMIT = 60
SIZE_LIMIT = 15_000

COUNT = re.compile(r"([0-9０-９]+)\s*(つ|段|個|点|項目|種類|件)")
NEXT = re.compile(r"次の\s*[0-9０-９]+\s*(つ|段|個|点|項目|種類|件)")
QUOTE = re.compile(r"^\s*(>\s?)*")
LIST = re.compile(r"^([-*]|\d+\.)\s")
TAG = re.compile(r"<(/?)([A-Za-z][A-Za-z0-9]*)")
BOLD = re.compile(r"\*\*[^*\n]+?\*\*")
ITALIC = re.compile(r"(?<![A-Za-z0-9*])\*(?=\S)[^*\n]+?(?<=\S)\*(?![A-Za-z0-9*])|(?<![A-Za-z0-9_])_(?=\S)[^_\n]+?(?<=\S)_(?![A-Za-z0-9_])")
SPACE = re.compile(rf"[{JA}][A-Za-z0-9]|[A-Za-z0-9][{JA}]")
HAS_JA = re.compile(rf"[{JA}]")
MEMORY = re.compile(r"/\.claude/projects/[^/]+/memory/")


def strip(line):
    line = re.sub(r"`[^`]*`", "", line)
    line = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", line)
    line = re.sub(r"<https?://[^>]*>", "", line)
    line = re.sub(r"https?://\S+", "", line)
    return re.sub(r"<!--.*?-->", "", line)


def kind(text):
    if not text:
        return "blank"
    if text.startswith("#"):
        return "heading"
    if text.startswith("|"):
        return "table"
    if LIST.match(text):
        return "list"
    if text.startswith(">"):
        return "quote"
    return "body"


def check(path):
    found = []
    size = os.path.getsize(path)
    if "/docs/" in path and size > SIZE_LIMIT:
        found.append((1, f"docs の 1 ファイルが 15KB を超えている（{size // 1000}KB）。節ごとに分ける"))
    html = os.path.basename(path).lower() == "readme.md" or "/docs/" in path
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    start = 0
    if lines and lines[0] == "---":
        end = next((i for i in range(1, len(lines)) if lines[i] == "---"), 0)
        start = end + 1
    rows = []
    fence = False
    for number, raw in enumerate(lines[start:], start + 1):
        if QUOTE.sub("", raw).lstrip().startswith(("```", "~~~")):
            fence = not fence
            rows.append((number, "", "code"))
            continue
        if fence:
            continue
        text = strip(raw)
        rows.append((number, text, kind(text.strip())))
    heading = None
    for index, (number, text, what) in enumerate(rows):
        if what == "heading":
            level = len(text) - len(text.lstrip("#"))
            if heading and level > heading[0] and not heading[1]:
                found.append((number, "見出しとすぐ下の小見出しの間に本文を置く"))
            heading = [level, False]
            continue
        if what in ("body", "quote") and heading:
            heading[1] = True
        if what in ("code", "blank"):
            continue
        after = [w for _, _, w in rows[index + 1 :] if w != "blank"]
        following = after[0] if after else None
        items = len(list(takewhile(lambda w: w == following, after)))
        if following == "table":
            items -= 2
        plain = re.sub(r"「[^」]*」", "", text)
        counts = {int(n) for n, _ in COUNT.findall(plain)}
        if NEXT.search(plain) or (what in ("body", "quote") and following in ("list", "table") and items >= 3 and items in counts):
            found.append((number, "一覧の前置きに項目の数を書かない"))
        for closing, name in TAG.findall(text):
            if not (html and name.lower() in HTML_TAGS):
                found.append((number, f"使ってよい HTML ではない（<{closing}{name}>）"))
                break
        if ITALIC.search(BOLD.sub("", text)):
            found.append((number, "斜体を使わない"))
        if SPACE.search(text):
            found.append((number, "日本語と英数字の間に半角スペースを入れる"))
        if what == "table":
            continue
        body = re.sub(r"<[^>]*>", "", text.strip())
        body = re.sub(r"^(>\s*)?([-*]|\d+\.)?\s*", "", body).replace("**", "")
        for sentence in body.split("。"):
            if HAS_JA.search(sentence) and len(sentence) + 1 > LIMIT:
                found.append((number, f"一文が {LIMIT} 字を超えている（{len(sentence) + 1} 字）"))
    return found


def main():
    if len(sys.argv) > 1:
        paths = sys.argv[1:]
    else:
        data = read_payload()
        if data is None:
            return
        paths = [tool_input(data).get("file_path", "")]
    report = []
    for path in map(os.path.abspath, filter(None, paths)):
        if path.endswith(".md") and os.path.isfile(path) and not MEMORY.search(path):
            report += [f"{path}:{n}: {m}" for n, m in check(path)]
    if report:
        print("文書の決まり（rules/docs-writing.md）に合わない箇所がある。直す。", file=sys.stderr)
        print("\n".join(report), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
