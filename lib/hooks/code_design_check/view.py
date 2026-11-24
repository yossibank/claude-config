import os
import re

from hooks.code_design_check.state import KOTLIN_TOP, block_end, next_code

PART_LIBRARY = "designsystem"
SWIFT_METRICS = {"CGFloat", "CGSize", "CGRect", "CGPoint", "CGVector", "EdgeInsets", "ScrollPosition", "ScrollGeometry", "Double", "Angle"}
KOTLIN_METRICS = {"Dp", "DpSize", "DpOffset", "Float", "Offset", "IntOffset", "Size", "IntSize", "Rect", "IntRect", "PaddingValues"}
ATTRIBUTES = r"(?:@\w+(?:\([^)]*\))?\s+)*"
SWIFT_ACCESS = r"(?:(?:public|package|internal|fileprivate|private)(?:\(set\))?\s+)*"
SWIFT_VALUE = r"var\s+(?P<name>\w+)\s*(?::\s*(?P<type>[^={]+?))?\s*(?:=\s*(?P<value>[^{]*?))?\s*$"
SWIFT_STATE = re.compile(r"^\s*" + ATTRIBUTES + r"@State\s+" + SWIFT_ACCESS + SWIFT_VALUE)
SWIFT_PREVIEW = re.compile(r"@Previewable\b")
SWIFT_LAYOUT = re.compile(r"^(\s*)" + SWIFT_ACCESS + r"(?:final\s+)?(?:struct|class)\s+Layout\b")
SWIFT_MEMBER = ATTRIBUTES + SWIFT_ACCESS + SWIFT_VALUE
SWIFT_BOX = re.compile(r"(?:Optional|Array|Set|Dictionary)<(.*)>")
HEAD = re.compile(r"[A-Z]\w*(?:\.[A-Z]\w*)*")
GENERIC = re.compile(r"<.*>$")
COMPOSABLE = re.compile(r"@Composable\b")
KOTLIN_ACCESS = r"(?:(?:public|internal|private|override|inline|suspend|operator)\s+)*"
KOTLIN_FUN = re.compile("^" + ATTRIBUTES + KOTLIN_ACCESS + r"fun\b")
KOTLIN_PREVIEW = "@Preview"
KOTLIN_MADE = re.compile(r"\b(?P<maker>mutable\w*State\w*Of)\s*(?:<(?P<generic>[^(]*)>)?\s*\((?P<held>.*)")
KOTLIN_NAMED = re.compile(r"\b(?:var|val)\s+(?P<name>\w+)\s*(?::\s*(?P<type>[^=]+?))?\s*(?:\bby\b|=)")
KOTLIN_LAYOUT = re.compile(r"^(\s*)(?:(?:public|internal|private)\s+)?class\s+Layout\b")
KOTLIN_MEMBER = KOTLIN_ACCESS + r"(?:var|val)\s+(?P<name>\w+)\b(?P<rest>.*)$"
KOTLIN_TYPED = re.compile(r"^\s*:\s*(?P<type>[^=]+?)\s*(?:\bby\b|=|$)")
KOTLIN_PLAIN = re.compile(r"=\s*(?P<held>.*)$")
KOTLIN_GETTER = re.compile(r"(?:^|\s)get\(\)")
KOTLIN_BOX = re.compile(r"(?:Map|List|Set|Array|MutableMap|MutableList|MutableSet)<(.*)>")
KOTLIN_MAKERS = {"mutableFloatStateOf": "Float", "mutableIntStateOf": "Int", "mutableLongStateOf": "Long", "mutableDoubleStateOf": "Double"}
KOTLIN_FLOAT = re.compile(r"-?[\d.]+f")
KOTLIN_DP = re.compile(r"-?[\d.]+\.dp")


def is_part_library(path):
    folders = os.path.normpath(os.path.realpath(path)).split(os.sep)[:-1]
    return any(folder.lower() == PART_LIBRARY for folder in folders)


def last_part(text, mark):
    depth = 0
    start = 0
    for index, char in enumerate(text):
        if char in "[<(":
            depth += 1
        elif char in "]>)":
            depth -= 1
        elif char == mark and depth == 0:
            start = index + 1
    return text[start:]


def swift_leaf(kind):
    kind = kind.strip()
    if kind.endswith(("?", "!")):
        return swift_leaf(kind[:-1])
    if kind.startswith("[") and kind.endswith("]"):
        return swift_leaf(last_part(kind[1:-1], ":"))
    found = SWIFT_BOX.fullmatch(kind)
    return swift_leaf(last_part(found.group(1), ",")) if found else kind


def kotlin_leaf(kind):
    kind = kind.strip()
    if kind.endswith("?"):
        return kotlin_leaf(kind[:-1])
    found = KOTLIN_BOX.fullmatch(kind)
    return kotlin_leaf(last_part(found.group(1), ",")) if found else kind


def head(value):
    found = HEAD.match(value.strip())
    return found.group(0) if found else ""


def swift_kind(found):
    return (found.group("type") or "").strip() or head(found.group("value") or "")


def bare(kind):
    return GENERIC.sub("", kind.strip().rstrip("?!"))


def swift_layouts(code):
    for index, line in enumerate(code):
        found = SWIFT_LAYOUT.match(line)
        if found and line.rstrip().endswith("{"):
            yield index, block_end(code, index, found.group(1)), found.group(1)


def check_swift_layout(code):
    for start, end, indent in swift_layouts(code):
        pattern = re.compile("^" + indent + "    " + SWIFT_MEMBER)
        for index in range(start + 1, end):
            found = pattern.match(code[index])
            if not found:
                continue
            name, kind = found.group("name"), swift_kind(found)
            if not kind:
                yield index + 1, f"Layout の値には、型を書く: {name}。置けるのは、寸法・位置・スクロールの型だけである"
            elif swift_leaf(kind) not in SWIFT_METRICS:
                yield index + 1, f"Layout に置けるのは、寸法・位置・スクロールの型だけにする: {name}。意味のある状態は、モデルの state に移す"


def check_swift_view(path, code):
    if is_part_library(path):
        return
    for index, line in enumerate(code):
        found = SWIFT_STATE.match(line)
        if not found or SWIFT_PREVIEW.search(line):
            continue
        kind = swift_kind(found)
        name = bare(kind)
        if name.endswith("Model") or name == "Layout" or name.endswith(".Layout"):
            continue
        if kind and swift_leaf(kind) in SWIFT_METRICS:
            fix = "見た目の値は、入れ子の struct Layout にまとめる"
        else:
            fix = "意味のある状態は、モデルの state に移す"
        yield index + 1, f"View の @State に置けるのは、モデルと layout だけにする: {found.group('name')}。{fix}"
    yield from check_swift_layout(code)


def argument(text):
    depth = 0
    for index, char in enumerate(text):
        if char in "([{":
            depth += 1
        elif char in ")]}":
            if depth == 0:
                return text[:index]
            depth -= 1
    return text


def held_kind(held):
    held = held.strip()
    if KOTLIN_FLOAT.fullmatch(held):
        return "Float"
    if KOTLIN_DP.fullmatch(held):
        return "Dp"
    return head(held).split(".")[0]


def made_kind(kind, made):
    if kind:
        return kind.strip()
    if made.group("generic"):
        return made.group("generic").strip()
    return KOTLIN_MAKERS.get(made.group("maker")) or held_kind(argument(made.group("held")))


def member_kind(rest):
    typed = KOTLIN_TYPED.match(rest)
    made = KOTLIN_MADE.search(rest)
    if made:
        return made_kind(typed.group("type") if typed else "", made)
    if typed:
        return typed.group("type").strip()
    plain = KOTLIN_PLAIN.search(rest)
    return held_kind(plain.group("held")) if plain else ""


def kotlin_layouts(code):
    for index, line in enumerate(code):
        found = KOTLIN_LAYOUT.match(line)
        if found and line.rstrip().endswith("{"):
            yield index, block_end(code, index, found.group(1)), found.group(1)


def check_kotlin_layout(code):
    for start, end, indent in kotlin_layouts(code):
        pattern = re.compile("^" + indent + "    " + KOTLIN_MEMBER)
        for index in range(start + 1, end):
            found = pattern.match(code[index])
            if not found or KOTLIN_GETTER.search(found.group("rest") + next_code(code, index)):
                continue
            name, kind = found.group("name"), member_kind(found.group("rest"))
            if not kind:
                yield index + 1, f"Layout の値には、型を書く: {name}。置けるのは、寸法と位置の型だけである"
            elif kotlin_leaf(kind) not in KOTLIN_METRICS:
                yield index + 1, f"Layout に置けるのは、寸法と位置の型だけにする: {name}。意味のある状態は、モデルの State に移す"


def composable_lines(code):
    inside = False
    marks = ""
    for index, line in enumerate(code):
        if KOTLIN_TOP.match(line):
            is_fun = bool(KOTLIN_FUN.match(line))
            inside = is_fun and KOTLIN_PREVIEW not in marks + line
            marks = marks + line if line.startswith("@") and not is_fun else ""
        if inside:
            yield index, line


def check_kotlin_view(path, code):
    if is_part_library(path):
        return
    yield from check_kotlin_layout(code)
    if not any(COMPOSABLE.search(line) for line in code):
        return
    for index, line in composable_lines(code):
        made = KOTLIN_MADE.search(line)
        if not made:
            continue
        named = KOTLIN_NAMED.search(line[: made.start()])
        kind = made_kind(named.group("type") if named else "", made)
        label = f"{made.group('maker')}: {named.group('name')}" if named else made.group("maker")
        if kind and kotlin_leaf(kind) in KOTLIN_METRICS:
            fix = "見た目の値は、class Layout にまとめる"
        else:
            fix = "意味のある状態は、モデルの State に移す"
        yield index + 1, f"Composable の関数で、状態を直接作らない（{label}）。{fix}"
