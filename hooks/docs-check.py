import os
import re
import sys
from itertools import takewhile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from docs_headings import (  # noqa: E402
    check_heading_emoji_repeats,
    check_heading_names,
    check_headings,
    check_prose_toc,
    check_readme_order,
    check_toc,
    heading_level,
    section_titles,
)
from docs_rows import BOLD, check_list_endings, check_rows, check_short_lists  # noqa: E402
from hook_io import block_on_findings, notify, run_hook, target_paths  # noqa: E402
from md_blocks import fence_marks  # noqa: E402
from md_doc import CODE, LINK, body_start, read_doc, rule_problems, without_links  # noqa: E402

SIZE_LIMIT = 15_000
ALERTS = ["NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION"]
SHIELDS = "https://img.shields.io/"
INLINE_CODE_LIMIT = 40
NOTE_LINES = 3

ALERT = re.compile(r"^>\s*\[!([A-Za-z]+)\]")
TREE = re.compile(r"[├└]──")
DECORATION = re.compile(r"\[!\[[^\]]*\]\([^)]*\)\]\([^)]*\)|!\[[^\]]*\]\([^)]*\)|</?[A-Za-z][A-Za-z0-9]*(\s[^>]*)?/?>")
TREE_NOTE = re.compile(r"#|\s{2,}\S")
COMMAND = re.compile(
    r"^(\./|~/|/|\$\{|(make|git|gh|python3?|bash|sh|zsh|npx|npm|xcodebuild|xcrun|swift|jq|curl|rsync|mint|brew|pre-commit|claude)\s)"
)
MEMORY = re.compile(r"/\.claude/projects/[^/]+/memory/")
HANDOFF = re.compile(r"/\.claude/handoff\.md$")
TEMPLATE_README = re.compile(r"/templates/[^/]+/README\.md$")


def check_size(doc):
    size = os.path.getsize(doc.path)
    if doc.in_docs and size > SIZE_LIMIT:
        return [(1, f"docs の 1 ファイルが {SIZE_LIMIT // 1000}KB を超えている（{size // 1000}KB）。節ごとに分ける")]
    return []


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
    titles = section_titles(doc)
    found = []
    for body in tables(doc):
        firsts = [cells[0] for _, cells in body if len(cells) == 2]
        if len(firsts) == len(body) >= 2 and all(first in titles for first in firsts):
            found.append((body[0][0], "節の名前を並べた表は目次になる。表を消し、冒頭の文で決めることを書く"))
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
    block = []
    for number, (raw, (mark, info)) in enumerate(zip(lines[start:], fence_marks(lines[start:])), start + 1):
        if mark == "open":
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


def check_shields(doc):
    message = "shields.io のバッジは使わない。技術は scripts/docs-tech-icons.py の SVG にする"
    return [(number, message) for number, _, _, what in doc.rows if what != "code" and SHIELDS in doc.lines[number - 1]]


def is_entry_readme(doc):
    folder = os.path.dirname(os.path.abspath(doc.path))
    return doc.readme and (os.path.exists(os.path.join(folder, ".git")) or TEMPLATE_README.search(doc.path) is not None)


def check_readme_body(doc):
    found = []
    in_section = False
    for number, text, _, what in doc.rows:
        line = doc.lines[number - 1]
        if what == "heading":
            in_section = in_section or heading_level(text) >= 2
        elif what == "quote" and ALERT.match(text.strip()):
            found.append((number, "README にはアラートを使わない"))
        elif what == "body" and in_section and not is_decoration(line) and not is_link_only(line):
            found.append((number, "README の節には文の段落を書かない。表・図・画像・箇条書きにする"))
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
    (lambda doc: doc.human, check_shields),
    (is_entry_readme, check_readme_body),
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
    try:
        block_on_findings("文書の決まり（rules/docs-*.md）に合わない箇所がある。直す。", target_paths(".md"), check)
    finally:
        for problem in rule_problems():
            notify(f"docs-check: {problem}")


if __name__ == "__main__":
    run_hook("docs-check", main)
