import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import block_on_findings, run_hook, target_paths  # noqa: E402
from swift_source import mask  # noqa: E402

WIDTH = 100
INDENT = 4

LOGICAL = re.compile(r"&&|\|\|")
ASSIGN = re.compile(r"(?<![=!<>])=(?!=)")
RETURN = re.compile(r"^return\b")
DECLARATION = re.compile(r"^\s*(?:[@\w]+(?:\([^)]*\))?\s+)*(?:func\s+[^\s(]+|init[?!]?|subscript)(?:<[^>]*>)?\($")
CONTAINER = re.compile(
    r"^\s*(?:"
    r"(?:VStack|HStack|ZStack|LazyVStack|LazyHStack|LazyVGrid|LazyHGrid|Grid|GridRow|Group|Section|Form|List"
    r"|ScrollView|NavigationStack|ControlGroup|ToolbarItemGroup|ViewThatFits)\b(?:\(.*\))?"
    r"|#Preview(?:\(.*\))?"
    r"|(?:(?:private|fileprivate|public|internal)\s+)?var\s+\w+:\s*some\s+View"
    r")\s*\{$"
)
LEADING_NAME = re.compile(r"^#?[A-Za-z_][A-Za-z0-9_]*")
NOT_VIEW = re.compile(r"^(?:let|var|@|if\b|switch\b|for\b|#if\b)")
CONTINUATION = re.compile(r"^[.)\]}]")


def indent_of(line):
    return len(line) - len(line.lstrip(" "))


def ternary_condition(line, mark):
    depth = 0
    for index in range(mark - 1, -1, -1):
        c = line[index]
        if c in ")]":
            depth += 1
        elif c in "([":
            if depth == 0:
                return line[index + 1 : mark]
            depth -= 1
        elif depth == 0 and (c in ",{" or ASSIGN.match(line, index)):
            return line[index + 1 : mark]
    return line[:mark]


def check_ternary(code):
    for n, line in enumerate(code, 1):
        marks = [index for index in range(len(line)) if line.startswith(" ? ", index)]
        if any(line.find(" : ", mark) > 0 and LOGICAL.search(ternary_condition(line, mark)) for mark in marks):
            yield n, "条件に && か || がある三項演算子は、? と : の前で折り返す"


def check_declarations(code, lines):
    for index in range(len(code) - 2):
        if not DECLARATION.match(code[index]):
            continue
        parameter, closing = code[index + 1].strip(), code[index + 2].strip()
        if not parameter or parameter.endswith(",") or not closing.startswith(")"):
            continue
        joined = lines[index].rstrip() + lines[index + 1].strip() + lines[index + 2].strip()
        if len(joined) <= WIDTH:
            yield index + 1, "引数が 1 つの宣言は、100 字に収まれば 1 行に書く"


def block_end(code, start):
    base = indent_of(code[start])
    for index in range(start + 1, len(code)):
        line = code[index]
        if line.strip() and indent_of(line) <= base:
            return index
    return len(code)


def statements(code, lines, start, end):
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


def blank_between(lines, first, second):
    return any(not lines[index].strip() for index in range(first[1] + 1, second[0]))


def check_returns(code, lines):
    for start, line in enumerate(code):
        if not line.rstrip().endswith("{"):
            continue
        items = statements(code, lines, start, block_end(code, start))
        if len(items) < 2 or any(first != last for first, last in items):
            continue
        heads = [code[first].strip() for first, _ in items]
        if not RETURN.match(heads[-1]) or not all(head.startswith("let ") for head in heads[:-1]):
            continue
        for before, after in zip(items, items[1:]):
            if blank_between(lines, before, after):
                yield after[0] + 1, "1 行の let の並びと最後の 1 行の return だけのブロックには、空行を入れない"


def check_views(code, lines):
    for start, line in enumerate(code):
        if not CONTAINER.match(line):
            continue
        items = statements(code, lines, start, block_end(code, start))
        if len(items) < 2:
            continue
        heads = [code[first].strip() for first, _ in items]
        if any(NOT_VIEW.match(head) for head in heads):
            continue
        names = {LEADING_NAME.match(head).group(0) if LEADING_NAME.match(head) else head for head in heads}
        same = len(names) == 1 and all(first == last for first, last in items)
        for before, after in zip(items, items[1:]):
            blank = blank_between(lines, before, after)
            if same and blank:
                yield after[0] + 1, "同じ型の 1 行のビューが続く時は、間に空行を入れない"
            elif not same and not blank:
                yield after[0] + 1, "型が変わるビューと、複数行のビューを含む並びは、すべての間に空行を入れる"


def check(path):
    with open(path, encoding="utf-8") as file:
        text = file.read()
    lines = text.split("\n")
    code = mask(text)
    findings = [
        *check_ternary(code),
        *check_declarations(code, lines),
        *check_returns(code, lines),
        *check_views(code, lines),
    ]
    return sorted(findings)


def main():
    block_on_findings("Swift の決まり（rules/swift-*.md）に合わない箇所がある。直す。", target_paths(".swift"), check)


if __name__ == "__main__":
    run_hook("swift-style-check", main)
