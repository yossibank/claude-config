import re

from md_blocks import heading_of
from md_doc import EMOJI, bare, heading_emojis, readme_order, title_of

TOC_NAMES = 3
TOC_ITEM = re.compile(r"^([-*]|\d+\.)\s+\[[^\]]+\]\(#[^)]*\)\s*$")
TOC_TITLES = {"目次", "contents", "table of contents"}
NAME_SEPARATOR = re.compile(r"[・、。]")


def heading_level(text):
    return heading_of(text.strip())[0]


def section_titles(doc):
    return {title_of(text) for _, text, _, what in doc.rows if what == "heading" and heading_level(text) == 2}


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
        elif heading and (what in ("body", "quote") or (doc.readme and what != "blank")):
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


def check_heading_names(doc):
    found = []
    stack = [(0, set())]
    for number, text, _, what in doc.rows:
        if what != "heading":
            continue
        level = heading_level(text)
        title = title_of(text)
        if title.lower() in TOC_TITLES:
            found.append((number, "目次は GitHub が作るので、手で書かない"))
        while stack[-1][0] >= level:
            stack.pop()
        if title in stack[-1][1]:
            found.append((number, f"同じ親の下に、同じ名前の見出しを置かない（{title}）"))
        stack[-1][1].add(title)
        stack.append((level, set()))
    return found


def check_prose_toc(doc):
    titles = section_titles(doc)
    found = []
    for number, text, _, what in doc.rows:
        if what in ("code", "blank", "heading", "table"):
            continue
        names = {name.strip(" >") for name in NAME_SEPARATOR.split(text)} & titles
        if len(names) >= TOC_NAMES:
            found.append((number, "節の名前を並べた文は目次になる。消すか、文書で分かることを書く"))
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
