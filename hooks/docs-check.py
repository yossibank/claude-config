import os
import re
import sys
from itertools import takewhile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import block_on_findings, target_paths  # noqa: E402
from md_blocks import fence_marks  # noqa: E402
from md_doc import CODE, EMOJI, bare, body_emojis, body_start, heading_emojis, read_doc, readme_order, without_links  # noqa: E402

JA = r"々぀-ヺー-ヿ一-鿿"
HTML_TAGS = {"img", "picture", "source", "table", "thead", "tbody", "tr", "th", "td", "details", "summary"}
SENTENCE_LIMIT = 60
COMMA_LIMIT = 3
TOC_NAMES = 3
SENTENCES = 3
CELL_SENTENCES = 2
SIZE_LIMIT = 15_000
ALERTS = ["NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION"]
STATE_BADGES = ["workflow", "release", "license"]
INLINE_CODE_LIMIT = 40
NOTE_LINES = 3
SHORT_LIST = 2
TOC_TITLES = {"目次", "contents", "table of contents"}

COUNT = re.compile(r"([0-9０-９]+)\s*(つ|段|個|点|項目|種類|件)")
NEXT = re.compile(r"次の\s*[0-9０-９]+\s*(つ|段|個|点|項目|種類|件)")
LIST_ITEM = re.compile(r"^(\s*)(?:[-*]|\d+\.)\s+(.*)$")
TAG = re.compile(r"<(/?)([A-Za-z][A-Za-z0-9]*)")
BOLD = re.compile(r"\*\*[^*\n]+?\*\*")
ITALIC = re.compile(r"(?<![A-Za-z0-9*])\*(?=\S)[^*\n]+?(?<=\S)\*(?![A-Za-z0-9*])|(?<![A-Za-z0-9_])_(?=\S)[^_\n]+?(?<=\S)_(?![A-Za-z0-9_])")
SPACE = re.compile(rf"[{JA}][A-Za-z0-9]|[A-Za-z0-9][{JA}]")
HAS_JA = re.compile(rf"[{JA}]")
ALERT = re.compile(r"^>\s*\[!([A-Za-z]+)\]")
TREE = re.compile(r"[├└]──")
BADGE = re.compile(r"!\[[^\]]*\]\((https://img\.shields\.io/[^)\s]+)\)")
TOC_ITEM = re.compile(r"^([-*]|\d+\.)\s+\[[^\]]+\]\(#[^)]*\)\s*$")
DECORATION = re.compile(r"\[!\[[^\]]*\]\([^)]*\)\]\([^)]*\)|!\[[^\]]*\]\([^)]*\)|</?[A-Za-z][A-Za-z0-9]*(\s[^>]*)?/?>")
TREE_NOTE = re.compile(r"#|\s{2,}\S")
COMMAND = re.compile(
    r"^(\./|~/|/|\$\{|(make|git|gh|python3?|bash|sh|zsh|npx|npm|xcodebuild|xcrun|swift|jq|curl|rsync|mint|brew|pre-commit|claude)\s)"
)
MEMORY = re.compile(r"/\.claude/projects/[^/]+/memory/")
HANDOFF = re.compile(r"/\.claude/handoff\.md$")
POLITE = re.compile(r"(です|(?<![済冷覚澄励醒騙だすさ])(?<!はげ)ます|ました|ません)(?=[。！？!?]|\s*$)")
LINK = re.compile(r"!?\[[^\]]*\]\([^)]*\)|<https?://[^>]*>|https?://\S+")
QUOTED = re.compile(r"「[^」]*」")
NAME_SEPARATOR = re.compile(r"[・、。]")


def sentences_of(text):
    return [part for part in text.split("。") if HAS_JA.search(part)]


def heading_level(text):
    return len(text) - len(text.lstrip("#"))


def check_size(doc):
    size = os.path.getsize(doc.path)
    if doc.in_docs and size > SIZE_LIMIT:
        return [(1, f"docs の 1 ファイルが {SIZE_LIMIT // 1000}KB を超えている（{size // 1000}KB）。節ごとに分ける")]
    return []


def check_headings(doc):
    found = []
    heading = None
    marked = {}
    allowed = heading_emojis()
    for number, text, _, what in doc.rows:
        if what == "heading":
            level = heading_level(text)
            if heading and level > heading[0] and not heading[1]:
                found.append((number, "見出しとすぐ下の小見出しの間に本文を置く"))
            heading = [level, False]
            title = text.lstrip("#").strip()
            emojis = EMOJI.findall(title)
            if doc.for_claude and emojis:
                found.append((number, "Claude が読む文書の見出しに絵文字を付けない"))
            elif emojis and (len(emojis) > 1 or not title.startswith(emojis[0])):
                found.append((number, "見出しの絵文字は頭に 1 つだけにする"))
            if level == 2:
                marked[number] = bool(emojis)
                if emojis and doc.human and allowed and bare(emojis[0]) not in allowed:
                    found.append((number, f"## の見出しの絵文字は rules/docs-human.md の表から選ぶ（{emojis[0]}）"))
        elif what in ("body", "quote") and heading:
            heading[1] = True
    if doc.human and "/docs/decisions/" not in doc.path and marked and not all(marked.values()):
        first = min(number for number, has in marked.items() if not has)
        found.append((first, "人が読む文書の ## の見出しには、頭に絵文字を 1 つ付ける"))
    elif doc.human and len(set(marked.values())) > 1:
        first = min(number for number, has in marked.items() if has != marked[min(marked)])
        found.append((first, "## の見出しは、すべてに絵文字を付けるか、どれにも付けないかにそろえる"))
    return found


def check_heading_emoji_repeats(doc):
    found = []
    seen = set()
    for number, text, _, what in doc.rows:
        if what != "heading" or heading_level(text) != 2:
            continue
        emojis = EMOJI.findall(text)
        if not emojis:
            continue
        if bare(emojis[0]) in seen:
            found.append((number, f"## の見出しに同じ絵文字を 2 度使わない（{emojis[0]}）。節をまとめるか、別の絵文字にする"))
        seen.add(bare(emojis[0]))
    return found


def table_cells(line):
    return [cell.strip() for cell in line.replace("\\|", "\0").strip().strip("|").split("|")]


def tables(doc):
    current = []
    for index, row in enumerate(doc.rows):
        if row.what != "table":
            if current:
                yield current
            current = []
            continue
        if index == 0 or doc.rows[index - 1].what != "table" or set(row.text.strip()) <= set("|-: "):
            continue
        current.append((row.number, table_cells(doc.lines[row.number - 1])))
    if current:
        yield current


def check_table_first_column(doc):
    found = []
    for body in tables(doc):
        seen = set()
        for number, cells in body:
            if len(cells) == 2 and cells[0] and cells[0] in seen:
                found.append((number, f"表の 1 列目に同じ値を繰り返さない（{cells[0]}）。値ごとに見出しか箇条書きに分ける"))
            seen.add(cells[0])
    return found


def check_table_toc(doc):
    titles = {EMOJI.sub("", text.lstrip("#")).strip() for _, text, _, what in doc.rows if what == "heading" and heading_level(text) == 2}
    found = []
    for body in tables(doc):
        firsts = [cells[0] for _, cells in body if len(cells) == 2]
        if len(firsts) == len(body) >= 2 and all(first in titles for first in firsts):
            found.append((body[0][0], "節の名前を並べた表は目次になる。表を消し、冒頭の文で決めることを書く"))
    return found


def check_prose_toc(doc):
    titles = {EMOJI.sub("", text.lstrip("#")).strip() for _, text, _, what in doc.rows if what == "heading" and heading_level(text) == 2}
    found = []
    for number, text, _, what in doc.rows:
        if what in ("code", "blank", "heading", "table"):
            continue
        names = {name.strip(" >") for name in NAME_SEPARATOR.split(text)} & titles
        if len(names) >= TOC_NAMES:
            found.append((number, "節の名前を並べた文は目次になる。消すか、文書で分かることを書く"))
    return found


def check_heading_names(doc):
    found = []
    stack = [(0, set())]
    for number, text, _, what in doc.rows:
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


def check_readme_order(doc):
    order = readme_order()
    emojis = [emoji for emoji, _ in order]
    found = []
    top = 0
    for number, text, _, what in doc.rows:
        if what != "heading" or heading_level(text) != 2:
            continue
        marks = EMOJI.findall(text)
        rank = emojis.index(bare(marks[0])) if marks and bare(marks[0]) in emojis else len(emojis)
        if rank < top:
            names = "・".join(name for _, name in order)
            found.append((number, f"README の ## は {names}・ほかの節の順に並べる"))
        top = max(top, rank)
    return found


def is_link_only(line):
    rest = LINK.sub("", re.sub(r"^\s*>\s?", "", line))
    return LINK.search(line) is not None and not re.sub(r"[\s、・,/|。]", "", rest)


def is_decoration(line):
    return not DECORATION.sub("", line).strip()


def opening(doc):
    rows = doc.rows
    titles = [index for index, row in enumerate(rows) if row.what == "heading"]
    if not titles or heading_level(rows[titles[0]].text) != 1:
        return None, None
    after = next((row for row in rows[titles[0] + 1 :] if row.what != "blank"), None)
    return rows[titles[0]], after


def check_opening_sentence(doc):
    title, after = opening(doc)
    if title and not (after and after.what == "body" and not is_decoration(doc.lines[after.number - 1])):
        return [(title.number, "タイトルの直後に、何があるかを 1 文で書く")]
    return []


def check_opening_note(doc):
    title, after = opening(doc)
    if not title:
        return []
    alert = ALERT.match(after.text.strip()) if after else None
    if not (alert and alert.group(1).upper() == "NOTE"):
        return [(title.number, "README 以外の人が読む文書は、タイトルの直後に [!NOTE] を置く")]
    start = doc.rows.index(after) + 1
    quoted = takewhile(lambda row: row.what == "quote" and not ALERT.match(row.text.strip()), doc.rows[start:])
    lines = [row for row in quoted if not is_link_only(doc.lines[row.number - 1])]
    if len(lines) > NOTE_LINES:
        return [(after.number, f"冒頭の [!NOTE] は {NOTE_LINES} 行までにする（{len(lines)} 行）。分かることだけを書く")]
    return []


def check_sections(doc):
    found = []
    bolds = alerts = 0
    after_title = False
    for number, text, _, what in doc.rows:
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
        if alert and alert.group(1).upper() not in ALERTS:
            found.append((number, f"アラートは {'・'.join(ALERTS)} だけを使う（{alert.group(1)}）"))
        if alert and not (after_title and alert.group(1).upper() == "NOTE"):
            alerts += 1
            if alerts == 2:
                found.append((number, "アラートは、冒頭の [!NOTE] を除いて 1 節に 1 つまでにする"))
        after_title = False
    return found


def check_blocks(doc):
    lines = doc.lines
    start = body_start(lines)
    found = []
    language = ""
    block = []
    for number, (raw, (mark, info)) in enumerate(zip(lines[start:], fence_marks(lines[start:])), start + 1):
        if mark == "open":
            language = info
            block = []
            if not info:
                found.append((number, "コードブロックに言語を付ける。文字だけなら text にする"))
        elif mark == "close":
            found += check_tree(block)
        elif mark == "code":
            block.append((number, raw))
    return found


def check_tree(block):
    if not any(TREE.search(line) for _, line in block):
        return []
    names = ((number, line.strip().lstrip("│├└─ \u00a0")) for number, line in block)
    return [(number, "フォルダの木には名前だけを書く。説明は表に分ける") for number, name in names if TREE_NOTE.search(name)]


def check_toc(doc):
    found = []
    run = 0
    for number, text, _, what in doc.rows:
        if what == "heading" and heading_level(text) >= 2:
            break
        run = run + 1 if what == "list" and TOC_ITEM.match(doc.lines[number - 1].strip()) else 0
        if run == 2:
            found.append((number - 1, "目次は GitHub が作るので、手で書かない"))
    return found


def badges_of(doc):
    return [(number, url) for number, _, _, what in doc.rows if what != "code" for url in BADGE.findall(doc.lines[number - 1])]


def check_badges(doc):
    return check_badge_order(doc.lines, badges_of(doc))


def check_badge_order(lines, badges):
    found = []
    first_tech = last_state = None
    rank = 0
    dynamic_lines = {number for number, url in badges if "/badge/" not in url}
    for number, url in badges:
        if "/badge/" in url and (number in dynamic_lines or any(key in url.lower() for key in STATE_BADGES)):
            found.append((number, "状態の段は動的なバッジにする。/badge/ の固定のバッジを置かない"))
            continue
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


def check_inline_code(doc):
    found = []
    for number, _, _, what in doc.rows:
        if what in ("code", "blank", "heading"):
            continue
        for span in CODE.findall(without_links(doc.lines[number - 1])):
            if len(span) > INLINE_CODE_LIMIT and re.search(r"\s", span) and COMMAND.match(span):
                found.append((number, f"文の中に長いコマンドを書かない（{len(span)} 字）。コードブロックに出す"))
    return found


def check_preface(rows, index):
    number, text, _, what = rows[index]
    after = [row.what for row in rows[index + 1 :] if row.what != "blank"]
    following = after[0] if after else None
    items = len(list(takewhile(lambda w: w == following, after)))
    if following == "table":
        items -= 2
    plain = QUOTED.sub("", text)
    counts = {int(n) for n, _ in COUNT.findall(plain)}
    if NEXT.search(plain) or (what in ("body", "quote") and following in ("list", "table") and items >= 3 and items in counts):
        return [(number, "一覧の前置きに項目の数を書かない")]
    return []


def check_list_endings(doc):
    found = []
    groups = {}
    for number, _, spoken, what in doc.rows:
        match = LIST_ITEM.match(spoken) if what == "list" else None
        if not match:
            groups = {}
            continue
        indent, text = len(match.group(1)), match.group(2).strip()
        if text.startswith(("[ ]", "[x]")):
            continue
        groups = {key: value for key, value in groups.items() if key <= indent}
        ends = text.endswith("。")
        if "。" in QUOTED.sub("", text) and not ends:
            found.append((number, "中に「。」がある項目は、末尾も「。」で終える"))
        first, first_ends = groups.setdefault(indent, (number, ends))
        if first_ends != ends:
            found.append((number, f"{first} 行目からの一覧と文末をそろえる。どれも「。」で終えるか、どれにも付けない"))
    return found


def check_short_lists(doc):
    found = []
    groups = {}

    def close(deeper_than):
        for indent in [key for key in groups if key > deeper_than]:
            first, count, plain = groups.pop(indent)
            if plain and count <= SHORT_LIST:
                found.append((first, f"箇条書きを {count} 項目に使わない。文で書く"))

    def continues(row):
        return row.what in ("body", "code", "quote", "table") and doc.lines[row.number - 1].startswith((" ", "\t"))

    for index, row in enumerate(doc.rows):
        match = LIST_ITEM.match(row.spoken) if row.what == "list" else None
        if row.what == "blank":
            following = next((later for later in doc.rows[index + 1 :] if later.what != "blank"), None)
            if following and (following.what == "list" or continues(following)):
                continue
        if not match:
            if not continues(row):
                close(-1)
            continue
        indent, text = len(match.group(1)), match.group(2).strip()
        close(indent)
        plain = not re.match(r"\d+\.", row.spoken.strip()) and not text.startswith(("[ ]", "[x]"))
        first, count, was_plain = groups.get(indent, (row.number, 0, True))
        groups[indent] = (first, count + 1, was_plain and plain)
    close(-1)
    return found


def check_polite(row):
    if row.what not in ("body", "list", "table"):
        return []
    pieces = row.text.strip().strip("|").split("|") if row.what == "table" else [row.text]
    for piece in pieces:
        if POLITE.search(QUOTED.sub("", piece).strip()):
            return [(row.number, "敬体（です・ます）を使わない。常体（である・する）で書く")]
    return []


def check_marks(doc, row):
    number, text = row.number, row.text
    found = []
    for closing, name in TAG.findall(text):
        if not (doc.html and name.lower() in HTML_TAGS):
            found.append((number, f"使ってよい HTML ではない（<{closing}{name}>）"))
            break
    if ITALIC.search(BOLD.sub("", text)):
        found.append((number, "斜体を使わない"))
    if SPACE.search(text):
        found.append((number, "日本語と英数字の間に半角スペースを入れる"))
    emojis = {bare(emoji) for emoji in EMOJI.findall(text)}
    allowed = body_emojis()
    if doc.for_claude and emojis:
        found.append((number, "Claude が読む文書に絵文字を使わない"))
    elif allowed and emojis - allowed:
        found.append((number, "本文の絵文字は rules/docs-human.md の表にあるものだけを使う"))
    return found


def check_length(row):
    number, spoken, what = row.number, row.spoken, row.what
    found = []
    body = re.sub(r"<[^>]*>", "", spoken.strip())
    if what == "table":
        pieces = [cell for cell in body.strip("|").split("|") if not re.fullmatch(r"\s*:?-+:?\s*", cell)]
    else:
        pieces = [re.sub(r"^(>\s*)?([-*]|\d+\.)?\s*", "", body).replace("**", "")]
    for piece in pieces:
        parts = sentences_of(piece)
        for sentence in parts:
            if len(sentence.strip()) + 1 > SENTENCE_LIMIT:
                found.append((number, f"一文が {SENTENCE_LIMIT} 字を超えている（{len(sentence.strip()) + 1} 字）。句点で区切る"))
        for sentence in piece.split("。")[:-1]:
            if sentence.count("、") > COMMA_LIMIT:
                found.append((number, f"一文の読点は {COMMA_LIMIT} つまでにする（{sentence.count('、')} つ）。句点で区切るか、並べる語は箇条書きか表にする"))
        limit = CELL_SENTENCES if what == "table" else SENTENCES
        if len(parts) > limit:
            where = "表のセル" if what == "table" else "1 つの段落や項目"
            found.append((number, f"{where}は {limit} 文までにする。分けるか、箇条書きか表にする"))
    return found


def check_rows(doc):
    found = []
    for index, row in enumerate(doc.rows):
        if row.what in ("code", "blank", "heading"):
            continue
        found += check_preface(doc.rows, index)
        found += check_marks(doc, row)
        found += check_length(row)
        found += check_polite(row)
    return found


def always(doc):
    return True


def opens_with_sentence(doc):
    return doc.for_claude or doc.readme


CHECKS = [
    (always, check_size),
    (always, check_headings),
    (always, check_heading_names),
    (lambda doc: doc.human, check_heading_emoji_repeats),
    (lambda doc: "/docs/decisions/" not in doc.path, check_table_first_column),
    (always, check_table_toc),
    (always, check_prose_toc),
    (always, check_sections),
    (always, check_blocks),
    (always, check_toc),
    (always, check_badges),
    (always, check_list_endings),
    (always, check_short_lists),
    (lambda doc: doc.readme, check_readme_order),
    (lambda doc: doc.for_claude, check_inline_code),
    (opens_with_sentence, check_opening_sentence),
    (lambda doc: doc.human and not opens_with_sentence(doc), check_opening_note),
    (always, check_rows),
]


def check(path):
    if MEMORY.search(path) or HANDOFF.search(path):
        return []
    doc = read_doc(path)
    return sorted(found for applies, run in CHECKS if applies(doc) for found in run(doc))


def main():
    block_on_findings("文書の決まり（rules/docs-*.md）に合わない箇所がある。直す。", target_paths(".md"), check)


if __name__ == "__main__":
    main()
