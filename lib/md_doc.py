import functools
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import NamedTuple

from md_blocks import fence_marks, front_matter_end, table_under

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RULES = [os.path.join(ROOT, "rules", name) for name in ("docs-writing.md", "docs-claude.md", "docs-human.md")]

EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿⬀-⯿]️?")
CODE = re.compile(r"`([^`]*)`")
LIST = re.compile(r"^([-*]|\d+\.)\s")
FOR_CLAUDE = re.compile(r"(^|/)(CLAUDE|SKILL)\.md$|/(rules|agents|output-styles)/[^/]+\.md$")


class Row(NamedTuple):
    number: int
    text: str
    spoken: str
    what: str


@dataclass(frozen=True)
class Doc:
    path: str
    lines: list
    rows: list
    for_claude: bool
    readme: bool
    in_docs: bool
    human: bool
    html: bool


def bare(emoji):
    return emoji.replace("\ufe0f", "")


@functools.cache
def rule_table(heading, first_column):
    lines = []
    for path in RULES:
        try:
            lines += Path(path).read_text(encoding="utf-8").split("\n")
        except OSError:
            continue
    return table_under(lines, heading, first_column)


def heading_emojis():
    return {bare(row[1]): row[0] for row in rule_table("### 見出しの絵文字の表", "節")}


def body_emojis():
    return {bare(emoji) for row in rule_table("## 本文の絵文字", "分類") for emoji in EMOJI.findall(row[1])}


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


def body_start(lines):
    end = front_matter_end(lines)
    return 0 if end is None else end + 1


def rows_of(lines):
    start = body_start(lines)
    rows = []
    for number, (raw, (mark, _)) in enumerate(zip(lines[start:], fence_marks(lines[start:])), start + 1):
        if mark in ("open", "close"):
            rows.append(Row(number, "", "", "code"))
            continue
        if mark == "code":
            continue
        linked = without_links(raw)
        plain = CODE.sub("", linked)
        spoken = CODE.sub(r"\1", linked)
        rows.append(Row(number, plain, spoken, kind(plain.strip())))
    return rows


def read_doc(path):
    lines = Path(path).read_text(encoding="utf-8", errors="replace").split("\n")
    readme = os.path.basename(path).lower() == "readme.md"
    in_docs = "/docs/" in path
    return Doc(
        path=path,
        lines=lines,
        rows=rows_of(lines),
        for_claude=bool(FOR_CLAUDE.search(path)),
        readme=readme,
        in_docs=in_docs,
        human=readme or in_docs or "/spec/" in path,
        html=readme or in_docs,
    )
