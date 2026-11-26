import re

from hooks.docs_check.rows import tables
from md_doc import CODE, EMOJI

REASON = "💡 理由"
REJECT = "❌ 却下"
REASON_WORDS = {"理由"}
REJECT_WORDS = {"却下", "却下した案", "却下案", "選ばなかった案"}
LABEL_EMOJIS = {"💡", "❌"}

STRIKE = re.compile(r"~~")
STRUCK = re.compile(r"~~[^~]+~~")
REJECTION = re.compile(r"^~~[^~]+~~\s*\S")
COLOR = re.compile(r"\\color\s*\{")


def in_decisions(doc):
    return "/docs/decisions/" in doc.path


def label_of(cell):
    return EMOJI.sub("", cell).strip()


def is_label(cell):
    label = label_of(cell)
    return label in REASON_WORDS | REJECT_WORDS or any(emoji in cell for emoji in LABEL_EMOJIS)


def rejection_lines(doc):
    if not in_decisions(doc):
        return set()
    return {number for body in tables(doc) for number, cells in body if cells[0] == REJECT}


def check_decision_rows(doc):
    found = []
    for body in tables(doc):
        rejected = False
        for number, cells in body:
            first = cells[0]
            if not is_label(first):
                continue
            if first not in (REASON, REJECT):
                found.append((number, f"理由と却下の行の 1 列目は `{REASON}`・`{REJECT}` にする（{first}）"))
                continue
            if first == REASON and rejected:
                found.append((number, "理由の行は、却下の行より前に置く"))
            if first != REJECT:
                continue
            rejected = True
            content = cells[1] if len(cells) > 1 else ""
            if len(STRUCK.findall(content)) > 1:
                found.append((number, "却下の行には案を 1 つだけ書く。案ごとに行を分ける"))
            elif not REJECTION.match(content):
                found.append((number, "却下の行は `~~案の名前~~ 却下の理由` の形にする。理由の分からない案は行ごと消す"))
    return found


def check_strikes(doc):
    allowed = rejection_lines(doc)
    found = []
    for row in doc.rows:
        if row.what in ("code", "math", "blank") or row.number in allowed:
            continue
        if STRIKE.search(row.text):
            found.append((row.number, "取り消し線は、decisions の却下の行の案の名前だけに引く"))
    return found


def check_colors(doc):
    found = []
    for row in doc.rows:
        if row.what == "code":
            continue
        if COLOR.search(CODE.sub("", doc.lines[row.number - 1])):
            found.append((row.number, "文字の色（`$\\color`）を使わない。GitHub の外では効かない"))
    return found
