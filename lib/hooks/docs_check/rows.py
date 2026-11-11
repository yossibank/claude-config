import re

from md_doc import EMOJI, bare, body_emojis

JA = r"々぀-ヺー-ヿ一-鿿"
HTML_TAGS = {"img", "picture", "source", "table", "thead", "tbody", "tr", "th", "td", "details", "summary"}
SENTENCE_LIMIT = 60
COMMA_LIMIT = 3
SENTENCES = 3
CELL_SENTENCES = 2
SHORT_LIST = 2
COUNT = re.compile(r"([0-9０-９]+)\s*(つ|段|個|点|項目|種類|件)")
NEXT = re.compile(r"次の\s*[0-9０-９]+\s*(つ|段|個|点|項目|種類|件)")
LIST_ITEM = re.compile(r"^(\s*)(?:[-*]|\d+\.)\s+(.*)$")
TAG = re.compile(r"<(/?)([A-Za-z][A-Za-z0-9]*)")
BOLD = re.compile(r"\*\*[^*\n]+?\*\*")
ITALIC = re.compile(r"(?<![A-Za-z0-9*])\*(?=\S)[^*\n]+?(?<=\S)\*(?![A-Za-z0-9*])|(?<![A-Za-z0-9_])_(?=\S)[^_\n]+?(?<=\S)_(?![A-Za-z0-9_])")
SPACE = re.compile(rf"[{JA}][A-Za-z0-9]|[A-Za-z0-9][{JA}]")
HAS_JA = re.compile(rf"[{JA}]")
POLITE = re.compile(r"(です|(?<![済冷覚澄励醒騙だすさ])(?<!はげ)ます|ました|ません)(?=[。！？!?]|\s*$)")
QUOTED = re.compile(r"「[^」]*」")


def sentences_of(text):
    return [part for part in text.split("。") if HAS_JA.search(part)]


def following_kinds(rows):
    kinds = [row.what for row in rows if row.what != "blank"]
    runs = [1] * len(kinds)
    for index in range(len(kinds) - 2, -1, -1):
        if kinds[index] == kinds[index + 1]:
            runs[index] = runs[index + 1] + 1
    found = [(None, 0)] * len(rows)
    next_kind = len(kinds)
    for index in range(len(rows) - 1, -1, -1):
        if next_kind < len(kinds):
            found[index] = (kinds[next_kind], runs[next_kind])
        if rows[index].what != "blank":
            next_kind -= 1
    return found


def check_preface(row, following, items):
    number, text, _, what = row
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
    followings = following_kinds(doc.rows)
    for index, row in enumerate(doc.rows):
        if row.what in ("code", "blank", "heading"):
            continue
        found += check_preface(row, *followings[index])
        found += check_marks(doc, row)
        found += check_length(row)
        found += check_polite(row)
    return found
