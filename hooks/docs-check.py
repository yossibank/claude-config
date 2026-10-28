import functools
import os
import re
import sys
from itertools import takewhile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "lib"))

from hook_io import read_payload, tool_input  # noqa: E402
from md_blocks import QUOTE, front_matter_end, is_fence  # noqa: E402

RULES = os.path.join(ROOT, "rules", "docs-writing.md")

JA = r"々぀-ヺー-ヿ一-鿿"
HTML_TAGS = {"img", "picture", "source", "table", "thead", "tbody", "tr", "th", "td", "details", "summary"}
LIMIT = 60
SENTENCES = 3
CELL_SENTENCES = 2
SIZE_LIMIT = 15_000
BODY_EMOJI = {"✅", "🚧", "⬜", "🍎", "🤖", "🧩", "🔴", "🟠", "🟡", "⚪"}
ALERTS = ["NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION"]
STATE_BADGES = ["workflow", "release", "license"]
INLINE_CODE_LIMIT = 40
TOC_TITLES = {"目次", "contents", "table of contents"}

COUNT = re.compile(r"([0-9０-９]+)\s*(つ|段|個|点|項目|種類|件)")
NEXT = re.compile(r"次の\s*[0-9０-９]+\s*(つ|段|個|点|項目|種類|件)")
LIST = re.compile(r"^([-*]|\d+\.)\s")
TAG = re.compile(r"<(/?)([A-Za-z][A-Za-z0-9]*)")
BOLD = re.compile(r"\*\*[^*\n]+?\*\*")
ITALIC = re.compile(r"(?<![A-Za-z0-9*])\*(?=\S)[^*\n]+?(?<=\S)\*(?![A-Za-z0-9*])|(?<![A-Za-z0-9_])_(?=\S)[^_\n]+?(?<=\S)_(?![A-Za-z0-9_])")
SPACE = re.compile(rf"[{JA}][A-Za-z0-9]|[A-Za-z0-9][{JA}]")
HAS_JA = re.compile(rf"[{JA}]")
EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿⬀-⯿]️?")
CODE = re.compile(r"`([^`]*)`")
ALERT = re.compile(r"^>\s*\[!([A-Za-z]+)\]")
FENCE = re.compile(r"^(`{3,}|~{3,})(.*)$")
TREE = re.compile(r"[├└]──")
BADGE = re.compile(r"!\[[^\]]*\]\((https://img\.shields\.io/[^)\s]+)\)")
TOC_ITEM = re.compile(r"^([-*]|\d+\.)\s+\[[^\]]+\]\(#[^)]*\)\s*$")
MEMORY = re.compile(r"/\.claude/projects/[^/]+/memory/")
FOR_CLAUDE = re.compile(r"(^|/)(CLAUDE|SKILL)\.md$|/(rules|agents)/[^/]+\.md$")


def bare(emoji):
    return emoji.replace("\ufe0f", "")


@functools.cache
def rule_table(heading, first_column):
    try:
        lines = open(RULES, encoding="utf-8").read().split("\n")
    except OSError:
        return []
    if heading not in lines:
        return []
    tables = [[]]
    for line in lines[lines.index(heading) + 1 :]:
        if line.startswith("#"):
            break
        if line.startswith("|"):
            tables[-1].append([cell.strip().strip("`") for cell in line.strip().strip("|").split("|")])
        elif tables[-1]:
            tables.append([])
    return next((table[2:] for table in tables if table and table[0][0] == first_column), [])


def heading_emojis():
    return {bare(row[1]): row[0] for row in rule_table("### 見出しの絵文字", "節")}


def readme_order():
    emojis = heading_emojis()
    order = []
    for row in rule_table("## README の形", "順"):
        emoji = next((emoji for emoji, names in emojis.items() if row[1] in names.split("、")), None)
        if emoji:
            order.append((emoji, row[1]))
    return order


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
    end = front_matter_end(lines)
    start = 0 if end is None else end + 1
    rows = []
    fence = False
    for number, raw in enumerate(lines[start:], start + 1):
        if is_fence(raw):
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
        return [(1, f"docs の 1 ファイルが {SIZE_LIMIT // 1000}KB を超えている（{size // 1000}KB）。節ごとに分ける")]
    return []


def check_headings(rows, for_claude, readme):
    found = []
    heading = None
    marked = {}
    allowed = heading_emojis()
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
                if emojis and not for_claude and allowed and bare(emojis[0]) not in allowed:
                    found.append((number, f"## の見出しの絵文字は rules/docs-writing.md の表から選ぶ（{emojis[0]}）"))
        elif what in ("body", "quote") and heading:
            heading[1] = True
    if readme and marked and not all(marked.values()):
        first = min(number for number, has in marked.items() if not has)
        found.append((first, "README の ## の見出しには、頭に絵文字を 1 つ付ける"))
    elif len(set(marked.values())) > 1:
        first = min(number for number, has in marked.items() if has != marked[min(marked)])
        found.append((first, "## の見出しは、すべてに絵文字を付けるか、どれにも付けないかにそろえる"))
    return found


def heading_level(text):
    return len(text) - len(text.lstrip("#"))


def check_heading_names(rows):
    found = []
    stack = [(0, set())]
    for number, text, _, what in rows:
        if what != "heading":
            continue
        level = heading_level(text)
        title = EMOJI.sub("", text.lstrip("#")).strip()
        if title.lower() in TOC_TITLES:
            found.append((number, "目次は GitHub が作るので、手で書かない"))
        while stack[-1][0] >= level:
            stack.pop()
        if title in stack[-1][1]:
            found.append((number, f"同じ親の下に、同じ名前の見出しを置かない（{title}）"))
        stack[-1][1].add(title)
        stack.append((level, set()))
    return found


def check_readme_order(rows):
    order = readme_order()
    emojis = [emoji for emoji, _ in order]
    found = []
    top = 0
    for number, text, _, what in rows:
        if what != "heading" or heading_level(text) != 2:
            continue
        marks = EMOJI.findall(text)
        rank = emojis.index(bare(marks[0])) if marks and bare(marks[0]) in emojis else len(emojis)
        if rank < top:
            names = "・".join(name for _, name in order)
            found.append((number, f"README の ## は {names}・ほかの節の順に並べる"))
        top = max(top, rank)
    return found


def check_opening(rows, want):
    titles = [index for index, row in enumerate(rows) if row[3] == "heading"]
    if not titles or heading_level(rows[titles[0]][1]) != 1:
        return []
    index = titles[0]
    after = next((row for row in rows[index + 1 :] if row[3] != "blank"), None)
    alert = ALERT.match(after[1].strip()) if after else None
    if want == "note" and not (alert and alert.group(1) == "NOTE"):
        return [(rows[index][0], "README 以外の人が読む文書は、タイトルの直後に [!NOTE] を置く")]
    if want == "sentence" and not (after and after[3] == "body"):
        return [(rows[index][0], "タイトルの直後に、何があるかを 1 文で書く")]
    return []


def check_sections(rows):
    found = []
    bolds = alerts = 0
    after_title = False
    for number, text, _, what in rows:
        if what == "heading":
            bolds = alerts = 0
            after_title = heading_level(text) == 1
            continue
        if what in ("code", "blank"):
            continue
        before, bolds = bolds, bolds + len(BOLD.findall(text))
        if before < 2 <= bolds:
            found.append((number, "太字は 1 節に 1 か所までにする"))
        alert = ALERT.match(text.strip()) if what == "quote" else None
        if alert and alert.group(1) not in ALERTS:
            found.append((number, f"アラートは {'・'.join(ALERTS)} だけを使う（{alert.group(1)}）"))
        if alert and not (after_title and alert.group(1) == "NOTE"):
            alerts += 1
            if alerts == 2:
                found.append((number, "アラートは、冒頭の [!NOTE] を除いて 1 節に 1 つまでにする"))
        after_title = False
    return found


def check_blocks(lines):
    end = front_matter_end(lines)
    start = 0 if end is None else end + 1
    found = []
    opener = None
    block = []
    for number, raw in enumerate(lines[start:], start + 1):
        line = QUOTE.sub("", raw).lstrip()
        match = FENCE.match(line)
        if opener is None:
            if match:
                opener = (match.group(1), match.group(2).strip())
                block = []
                if not opener[1]:
                    found.append((number, "コードブロックに言語を付ける。文字だけなら text にする"))
            continue
        closing = match and match.group(1)[0] == opener[0][0] and len(match.group(1)) >= len(opener[0])
        if closing and not match.group(2).strip():
            if opener[1] == "text":
                found += check_tree(block)
            opener = None
            continue
        block.append((number, raw))
    return found


def check_tree(block):
    if not any(TREE.search(line) for _, line in block):
        return []
    names = ((number, line.strip().lstrip("│├└─ \u00a0")) for number, line in block)
    return [(number, "フォルダの木には名前だけを書く。説明は表に分ける") for number, name in names if re.search(r"\s", name)]


def check_toc(rows, lines):
    found = []
    run = 0
    for number, _, _, what in rows:
        run = run + 1 if what == "list" and TOC_ITEM.match(lines[number - 1].strip()) else 0
        if run == 2:
            found.append((number - 1, "目次は GitHub が作るので、手で書かない"))
    return found


def check_badges(rows, lines):
    badges = [(number, url) for number, _, _, what in rows if what != "code" for url in BADGE.findall(lines[number - 1])]
    found = []
    first_tech = last_state = None
    rank = 0
    for number, url in badges:
        if "/badge/" in url:
            first_tech = first_tech or number
            continue
        if first_tech:
            found.append((number, "バッジは、状態の段を技術の段より先に並べる"))
            continue
        state = next((index for index, key in enumerate(STATE_BADGES) if key in url), None)
        if state is not None and state < rank:
            found.append((number, "状態のバッジは CI → リリース → ライセンスの順に並べる"))
        rank = max(rank, state or 0)
        last_state = number
    between = range(last_state or 0, (first_tech or 0) + 1)
    if first_tech and last_state and last_state <= first_tech and all(lines[n - 1].strip() for n in between):
        found.append((first_tech, "状態と技術のバッジの段の間を、空行で分ける"))
    return found


def check_inline_code(rows, lines):
    found = []
    for number, _, _, what in rows:
        if what in ("code", "blank", "heading"):
            continue
        for span in CODE.findall(without_links(lines[number - 1])):
            if len(span) > INLINE_CODE_LIMIT and re.search(r"\s", span):
                found.append((number, f"文の中に長いコマンドを書かない（{len(span)} 字）。コードブロックに出す"))
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
        limit = CELL_SENTENCES if what == "table" else SENTENCES
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
    found += check_heading_names(rows) + check_sections(rows) + check_blocks(lines)
    found += check_toc(rows, lines) + check_badges(rows, lines)
    if readme:
        found += check_readme_order(rows)
    if for_claude:
        found += check_inline_code(rows, lines)
    if for_claude or readme:
        found += check_opening(rows, "sentence")
    elif "/docs/" in path or "/spec/" in path:
        found += check_opening(rows, "note")
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
