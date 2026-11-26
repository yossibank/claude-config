import re

from hooks.docs_check.rows import COMMA_LIMIT, HAS_JA, LIST_ITEM, is_separator, pieces_of, table_cells, tables
from md_doc import BARE_LINK

TABLE_ROW_LIMIT = 200
CELL_LINK_LIMIT = 3
ALERT_ITEM_LIMIT = 8
DOT_WORD_LIMIT = 6

ALERT = re.compile(r"^\s*>\s*\[![A-Za-z]+\]")
QUOTED_ITEM = re.compile(r"^\s*>\s?(.*)$")
CELL_LINK = re.compile(rf"(?<!!)\[[^\]]*\]\([^)]*\)|{BARE_LINK.pattern}")
LEADING_CODE = re.compile(r"^`([^`]+)`")
WORD = r"[^\s・、。|「」（）()]+"
DOT_RUN = re.compile(rf"{WORD}(?:・{WORD}){{{DOT_WORD_LIMIT},}}")


def check_table_rows(doc):
    found = []
    for row in doc.rows:
        if row.what != "table" or is_separator(row):
            continue
        length = len(re.sub(r"\s*\|\s*", "", row.spoken.strip()))
        if length > TABLE_ROW_LIMIT:
            found.append((row.number, f"表の 1 行が {TABLE_ROW_LIMIT} 字を超えている（{length} 字）。行か列を分ける"))
        links = max(len(CELL_LINK.findall(cell)) for cell in table_cells(doc.lines[row.number - 1]))
        if links > CELL_LINK_LIMIT:
            found.append((row.number, f"表の 1 つのセルのリンクは {CELL_LINK_LIMIT} つまでにする（{links} つ）。行を分ける"))
    return found


def check_table_first_code(doc):
    found = []
    for body in tables(doc):
        before = None
        for number, cells in body:
            code = LEADING_CODE.match(cells[0]) if len(cells) == 2 else None
            if code and before and code.group(1) == before[0] and cells[0] != before[1]:
                found.append((number, f"2 列の表の 1 列目の頭に、同じコードを続けない（`{code.group(1)}`）。値ごとに見出しか箇条書きに分ける"))
            before = (code.group(1), cells[0]) if code else None
    return found


def alert_items(doc):
    start = count = None
    for row in doc.rows:
        line = doc.lines[row.number - 1]
        if row.what != "quote" or ALERT.match(line):
            if count:
                yield start, count
            start, count = (row.number, 0) if ALERT.match(line) else (None, None)
            continue
        quoted = QUOTED_ITEM.match(line)
        if count is not None and quoted and LIST_ITEM.match(quoted.group(1)):
            count += 1
    if count:
        yield start, count


def check_alert_lists(doc):
    message = f"アラートの中の箇条書きは {ALERT_ITEM_LIMIT} 項目までにする（{{}} 項目）。本文の表か箇条書きに出す"
    return [(start, message.format(count)) for start, count in alert_items(doc) if count > ALERT_ITEM_LIMIT]


def check_words(doc):
    found = []
    for row in doc.rows:
        if row.what in ("code", "math", "blank", "heading") or is_separator(row):
            continue
        for piece in pieces_of(row):
            last = piece.split("。")[-1]
            if HAS_JA.search(last) and last.count("、") > COMMA_LIMIT:
                found.append((row.number, f"句点の無い項目やセルも、読点は {COMMA_LIMIT} つまでにする（{last.count('、')} つ）。並べる語は箇条書きか表にする"))
        dots = DOT_RUN.search(row.spoken)
        if dots:
            words = dots.group(0).count("・") + 1
            found.append((row.number, f"「・」で並べる語は {DOT_WORD_LIMIT} つまでにする（{words} 語）。箇条書きか表にする"))
    return found
