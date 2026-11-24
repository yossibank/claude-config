import re

from hooks.code_design_check.state import (
    KOTLIN_CLASS,
    KOTLIN_GROUP,
    KOTLIN_STATE,
    SWIFT_ACCESS,
    SWIFT_ATTRIBUTES,
    block_end,
    kotlin_parts,
    next_code,
    observable_classes,
    stored_properties,
)

SOURCE_TYPE = r"(?:\w+\.)*\w*(?:Database|Clock)\b"
SWIFT_DIRECT = (
    SWIFT_ATTRIBUTES + SWIFT_ACCESS + r"(?:let|var)\s+(?P<name>\w+)\s*"
    r"(?::\s*(?:any\s+)?" + SOURCE_TYPE + r"[?!]?\s*(?:=.*)?|=\s*" + SOURCE_TYPE + r"[.(].*)$"
)
SWIFT_OPEN_VAR = re.compile(r"^\s*" + SWIFT_ATTRIBUTES + r"public\s+var\s+(\w+)")
SWIFT_DEPENDENCIES_TYPE = re.compile(r"^(\s*)" + SWIFT_ACCESS + r"struct\s+\w*Dependencies\b.*\{\s*$")
SWIFT_PUBLIC_MEMBER = SWIFT_ATTRIBUTES + r"public\s+(?:let|var)\s+(\w+)"
KOTLIN_DIRECT = re.compile(
    r"^    (?:(?:public|internal|private|override)\s+)*va[lr]\s+(?P<name>\w+)\s*"
    r"(?::\s*" + SOURCE_TYPE + r"|=\s*" + SOURCE_TYPE + r"[.(])"
)
KOTLIN_HELD = re.compile(r"^    (?P<words>(?:\w+\s+)*)va[lr]\s+dependencies\b")
KOTLIN_INPUT_VAR = re.compile(r"^        (?P<words>(?:\w+\s+)*)var\s+(?P<name>\w+)")
KOTLIN_SETTER = re.compile(r"^\s*(?:internal|private)\s+set\b")
KOTLIN_CLOSED = re.compile(r"\b(?:internal|private)\b")
KOTLIN_MUTABLE = re.compile(
    r"\bMutable(?:List|Set|Map|Collection)\b|\bmutable(?:List|Set|Map|StateList|StateMap)Of\b|\b(?:ArrayList|HashMap|HashSet|ArrayDeque)\b"
)


def is_input(name):
    return name.endswith("Input")


def check_swift_shape(code):
    for start, end, name, indent in observable_classes(code):
        direct = re.compile("^" + indent + "    " + SWIFT_DIRECT)
        for index in range(start + 1, end):
            found = direct.match(code[index])
            if found:
                yield index + 1, f"{name} は DB と時計を直接持たない: {found.group('name')}。dependencies にまとめ、値は state・input・output に分ける"
        if not is_input(name):
            continue
        for index, _ in stored_properties(code, start, end, indent):
            found = SWIFT_OPEN_VAR.match(code[index])
            if found:
                yield index + 1, f"{name} の public な var は、public internal(set) にする: {found.group(1)}。input に書くのは、モデルの関数だけにする"
    for start, line in enumerate(code):
        head = SWIFT_DEPENDENCIES_TYPE.match(line)
        if not head:
            continue
        member = re.compile("^" + head.group(1) + "    " + SWIFT_PUBLIC_MEMBER)
        for index in range(start + 1, block_end(code, start, head.group(1))):
            found = member.match(code[index])
            if found:
                yield index + 1, f"Dependencies の中身を public にしない: {found.group(1)}。DB と時計は、モデルの関数だけが使う"


def input_findings(code, name):
    for start, end, part in kotlin_parts(code):
        if part != "Input":
            continue
        for index in range(start + 1, end):
            if KOTLIN_MUTABLE.search(code[index]):
                yield index + 1, f"{name} の Input に、書き換えられる集まりを置かない。List・Set・Map で持ち、モデルの関数が入れ替える"
            found = KOTLIN_INPUT_VAR.match(code[index])
            if found and not KOTLIN_CLOSED.search(found.group("words")) and not KOTLIN_SETTER.match(next_code(code, index)):
                yield index + 1, f"{name} の Input の var は、internal set にする: {found.group('name')}。input に書くのは、モデルの関数だけにする"


def check_kotlin_shape(code):
    name = next((found.group(1) for line in code if (found := KOTLIN_CLASS.match(line))), "クラス")
    is_model = any(KOTLIN_GROUP.match(line) or KOTLIN_STATE.match(line) for line in code)
    for index, line in enumerate(code):
        held = KOTLIN_HELD.match(line)
        if held and "private" not in held.group("words").split():
            yield index + 1, f"{name} の dependencies は、private val にする。モデルの関数だけが使う"
        found = KOTLIN_DIRECT.match(line) if is_model else None
        if found:
            yield index + 1, f"{name} は DB と時計を直接持たない: {found.group('name')}。dependencies にまとめ、値は State・Input・Output に分ける"
    yield from input_findings(code, name)
