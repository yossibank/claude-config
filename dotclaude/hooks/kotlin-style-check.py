import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "lib"))

from hook_io import block_on_findings, run_hook, target_paths  # noqa: E402
from kotlin_source import mask  # noqa: E402

INDENT = 4
SHORT_BLOCK = 3

RETURN = re.compile(r"^return\b")
VAL = re.compile(r"^val\s")
ELVIS_RETURN = re.compile(r"\?:\s*return\b")
IF_OPEN = re.compile(r"^if\s*\(.*\)\s*\{$")
CONTAINER = re.compile(
    r"^(?:Column|Row|Box|BoxWithConstraints|LazyColumn|LazyRow|LazyVerticalGrid|LazyHorizontalGrid"
    r"|FlowRow|FlowColumn)\b"
)
LEADING_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*")
NOT_ELEMENT = re.compile(r"^(?:val|var|@|if\b|when\b|for\b|else\b)")
CONTINUATION = re.compile(r"^(?:[.)\]}]|\?[.:]|->|else\b|catch\b|finally\b)")


def indent_of(line):
    return len(line) - len(line.lstrip(" "))


def block_end(code, start):
    base = indent_of(code[start])
    for index in range(start + 1, len(code)):
        line = code[index]
        if line.strip() and indent_of(line) <= base:
            return index
    return len(code)


def statements(code, start, end):
    inner = indent_of(code[start]) + INDENT
    items = []
    for index in range(start + 1, end):
        text = code[index].strip()
        if not text:
            continue
        if indent_of(code[index]) == inner and not CONTINUATION.match(text):
            items.append([index, index])
        elif items:
            items[-1][1] = index
        else:
            return []
    return items


def blocks(code):
    for start, line in enumerate(code):
        if line.rstrip().endswith("{"):
            yield start, statements(code, start, block_end(code, start))


def blank_between(lines, first, second):
    return any(not lines[index].strip() for index in range(first[1] + 1, second[0]))


def head_of(code, start):
    text = code[start].strip()
    if not text.startswith(")"):
        return text
    base = indent_of(code[start])
    for index in range(start - 1, -1, -1):
        if code[index].strip() and indent_of(code[index]) == base:
            return code[index].strip()
    return text


def check_returns(code, lines):
    for _, items in blocks(code):
        if len(items) < 2 or any(first != last for first, last in items):
            continue
        heads = [code[first].strip() for first, _ in items]
        if not RETURN.match(heads[-1]) or not all(VAL.match(head) for head in heads[:-1]):
            continue
        for before, after in zip(items, items[1:]):
            if blank_between(lines, before, after):
                yield after[0] + 1, "1 行の val の並びと最後の 1 行の return だけのブロックには、空行を入れない"


def exits(code, items):
    short = len(items) <= SHORT_BLOCK and all(first == last for first, last in items)
    for position, (first, last) in enumerate(items):
        head = code[first].strip()
        following = code[items[position + 1][0]].strip() if position + 1 < len(items) else ""
        if first == last and ELVIS_RETURN.search(head) and not short and not VAL.match(following) and not RETURN.match(following):
            yield position
        elif IF_OPEN.match(head) and last - first == 2 and RETURN.match(code[first + 1].strip()):
            yield position


def check_exits(code, lines):
    for _, items in blocks(code):
        for position in exits(code, items):
            if position + 1 < len(items) and not blank_between(lines, items[position], items[position + 1]):
                yield items[position + 1][0] + 1, "早く抜ける行と、その後の処理の間には、空行を入れる"


def check_elements(code, lines):
    for start, items in blocks(code):
        if not CONTAINER.match(head_of(code, start)) or len(items) < 2:
            continue
        heads = [code[first].strip() for first, _ in items]
        if any(NOT_ELEMENT.match(head) for head in heads):
            continue
        names = {LEADING_NAME.match(head).group(0) if LEADING_NAME.match(head) else head for head in heads}
        same = len(names) == 1 and all(first == last for first, last in items)
        for before, after in zip(items, items[1:]):
            blank = blank_between(lines, before, after)
            if same and blank:
                yield after[0] + 1, "同じ Composable の 1 行の呼び出しが続く時は、間に空行を入れない"
            elif not same and not blank:
                yield after[0] + 1, "Composable が変わる並びと、複数行の呼び出しを含む並びは、すべての間に空行を入れる"


def check(path):
    with open(path, encoding="utf-8") as file:
        text = file.read()
    lines = text.split("\n")
    code = mask(text)
    findings = [
        *check_returns(code, lines),
        *check_exits(code, lines),
        *check_elements(code, lines),
    ]
    return sorted(set(findings))


def main():
    block_on_findings("Kotlin の決まり（rules/kotlin-*.md）に合わない箇所がある。直す。", target_paths(".kt"), check)


if __name__ == "__main__":
    run_hook("kotlin-style-check", main)
