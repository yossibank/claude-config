import os
import re
import sys
from itertools import takewhile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))

from hook_io import read_payload, tool_input  # noqa: E402

JA = r"々぀-ヺー-ヿ一-鿿"
HTML_TAGS = {"img", "picture", "source", "table", "thead", "tbody", "tr", "th", "td", "details", "summary"}
LIMIT = 60
SENTENCES = 3
SIZE_LIMIT = 15_000
BODY_EMOJI = {"✅", "🚧", "⬜", "🍎", "🤖", "🧩", "🔴", "🟠", "🟡", "⚪"}

COUNT = re.compile(r"([0-9０-９]+)\s*(つ|段|個|点|項目|種類|件)")
NEXT = re.compile(r"次の\s*[0-9０-９]+\s*(つ|段|個|点|項目|種類|件)")
QUOTE = re.compile(r"^\s*(>\s?)*")
LIST = re.compile(r"^([-*]|\d+\.)\s")
TAG = re.compile(r"<(/?)([A-Za-z][A-Za-z0-9]*)")
BOLD = re.compile(r"\*\*[^*\n]+?\*\*")
ITALIC = re.compile(r"(?<![A-Za-z0-9*])\*(?=\S)[^*\n]+?(?<=\S)\*(?![A-Za-z0-9*])|(?<![A-Za-z0-9_])_(?=\S)[^_\n]+?(?<=\S)_(?![A-Za-z0-9_])")
SPACE = re.compile(rf"[{JA}][A-Za-z0-9]|[A-Za-z0-9][{JA}]")
HAS_JA = re.compile(rf"[{JA}]")
EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿⬀-⯿]️?")
CODE = re.compile(r"`([^`]*)`")
MEMORY = re.compile(r"/\.claude/projects/[^/]+/memory/")
FOR_CLAUDE = re.compile(r"(^|/)(CLAUDE|SKILL)\.md$|/(rules|agents)/[^/]+\.md$")


def without_links(line):
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


def rows_of(lines):
    start = 0
    if lines and lines[0] == "---":
        start = next((i for i in range(1, len(lines)) if lines[i] == "---"), 0) + 1
    rows = []
    fence = False
    for number, raw in enumerate(lines[start:], start + 1):
        if QUOTE.sub("", raw).lstrip().startswith(("```", "~~~")):
            fence = not fence
            rows.append((number, "", "", "code"))
            continue
        if fence:
            continue
        linked = without_links(raw)
        plain = CODE.sub("", linked)
        spoken = CODE.sub(r"\1", linked)
        rows.append((number, plain, spoken, kind(plain.strip())))
    return rows


def sentences_of(text):
    return [part for part in text.split("。") if HAS_JA.search(part)]


def check_size(path):
    size = os.path.getsize(path)
    if "/docs/" in path and size > SIZE_LIMIT:
        return [(1, f"docs の 1 ファイルが 15KB を超えている（{size // 1000}KB）。節ごとに分ける")]
    return []


def check_headings(rows, for_claude, readme):
    found = []
    heading = None
    marked = {}
    for number, text, _, what in rows:
        if what == "heading":
            level = len(text) - len(text.lstrip("#"))
            if heading and level > heading[0] and not heading[1]:
                found.append((number, "見出しとすぐ下の小見出しの間に本文を置く"))
            heading = [level, False]
            title = text.lstrip("#").strip()
            emojis = EMOJI.findall(title)
            if for_claude and emojis:
                found.append((number, "Claude が読む文書の見出しに絵文字を付けない"))
            elif emojis and (len(emojis) > 1 or not title.startswith(emojis[0])):
                found.append((number, "見出しの絵文字は頭に 1 つだけにする"))
            if level == 2:
                marked[number] = bool(emojis)
        elif what in ("body", "quote") and heading:
            heading[1] = True
    if readme and marked and not all(marked.values()):
        first = min(number for number, has in marked.items() if not has)
        found.append((first, "README の ## の見出しには、頭に絵文字を 1 つ付ける"))
    elif len(set(marked.values())) > 1:
        first = min(number for number, has in marked.items() if has != marked[min(marked)])
        found.append((first, "## の見出しは、すべてに絵文字を付けるか、どれにも付けないかにそろえる"))
    return found


def check_preface(rows, index):
    number, text, _, what = rows[index]
    after = [w for _, _, _, w in rows[index + 1 :] if w != "blank"]
    following = after[0] if after else None
    items = len(list(takewhile(lambda w: w == following, after)))
    if following == "table":
        items -= 2
    plain = re.sub(r"「[^」]*」", "", text)
    counts = {int(n) for n, _ in COUNT.findall(plain)}
    if NEXT.search(plain) or (what in ("body", "quote") and following in ("list", "table") and items >= 3 and items in counts):
        return [(number, "一覧の前置きに項目の数を書かない")]
    return []


def check_marks(number, text, html, for_claude):
    found = []
    for closing, name in TAG.findall(text):
        if not (html and name.lower() in HTML_TAGS):
            found.append((number, f"使ってよい HTML ではない（<{closing}{name}>）"))
            break
    if ITALIC.search(BOLD.sub("", text)):
        found.append((number, "斜体を使わない"))
    if SPACE.search(text):
        found.append((number, "日本語と英数字の間に半角スペースを入れる"))
    emojis = {emoji.rstrip("️") for emoji in EMOJI.findall(text)}
    if for_claude and emojis:
        found.append((number, "Claude が読む文書に絵文字を使わない"))
    elif emojis - BODY_EMOJI:
        found.append((number, "本文の絵文字は rules/docs-writing.md の表にあるものだけを使う"))
    return found


def check_length(number, spoken, what):
    found = []
    body = re.sub(r"<[^>]*>", "", spoken.strip())
    if what == "table":
        pieces = [cell for cell in body.strip("|").split("|") if not re.fullmatch(r"\s*:?-+:?\s*", cell)]
    else:
        pieces = [re.sub(r"^(>\s*)?([-*]|\d+\.)?\s*", "", body).replace("**", "")]
    for piece in pieces:
        parts = sentences_of(piece)
        for sentence in parts:
            if len(sentence.strip()) + 1 > LIMIT:
                found.append((number, f"一文が {LIMIT} 字を超えている（{len(sentence.strip()) + 1} 字）。句点で区切る"))
        limit = 2 if what == "table" else SENTENCES
        if len(parts) > limit:
            where = "表のセル" if what == "table" else "1 つの段落や項目"
            found.append((number, f"{where}は {limit} 文までにする。分けるか、箇条書きか表にする"))
    return found


def check(path):
    for_claude = bool(FOR_CLAUDE.search(path))
    html = os.path.basename(path).lower() == "readme.md" or "/docs/" in path
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    rows = rows_of(lines)
    readme = os.path.basename(path).lower() == "readme.md"
    found = check_size(path) + check_headings(rows, for_claude, readme)
    for index, (number, text, spoken, what) in enumerate(rows):
        if what in ("code", "blank", "heading"):
            continue
        found += check_preface(rows, index)
        found += check_marks(number, text, html, for_claude)
        found += check_length(number, spoken, what)
    return sorted(found)


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
