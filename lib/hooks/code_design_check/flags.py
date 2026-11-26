import re

from hooks.code_design_check.state import PARTS, kotlin_parts, observable_classes

SWIFT_FLAG = re.compile(
    r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private)(?:\(set\))?\s+)*"
    r"var\s+(?P<name>\w+)\s*(?::\s*(?P<type>[^={]+?))?\s*(?:=\s*(?P<value>[^{]*?))?\s*$"
)
KOTLIN_FLAG = re.compile(
    r"^        (?:(?:public|internal|private|override)\s+)*var\s+(?P<name>\w+)\s*(?::\s*(?P<type>[^=]+?))?"
    r"\s+by\s+mutableStateOf\((?P<value>[^)]*)\)"
)
SHOWN = re.compile(
    r"isShowing[A-Z]\w*|isPresenting[A-Z]\w*|isConfirming[A-Z]\w*|is[A-Z]\w*Presented"
    r"|is\w*(?:Sheet|Alert|Dialog|Menu|Popover)(?:Open|Shown|Visible)"
    r"|show(?:ing)?\w*(?:Sheet|Alert|Dialog|Menu|Popover|Confirmation)"
)
LOADED = re.compile(r"(?:is|has)(?:[A-Z]\w*)?Loaded|is(?:[A-Z]\w*)?(?:Load|List|Fetch|Read)Failed")
STATE_LOADED = re.compile(r"isLoaded|hasLoaded|isLoadFailed|is\w*List(?:Loaded|Failed)")
RUNNING = re.compile(r"is(?:Saving|Working|Deleting|Submitting|Sending|Running|Busy|Processing)|working|busy")
FLAG_TYPES = {"Bool", "Boolean"}
FLAG_VALUES = {"true", "false"}


def flag_message(owner, part, name):
    """State と Input の Bool の名前から、使う部品を知らせる文を返す。当たらない時は None を返す。

    State の読んだ印は、ほかの画面の読み込みを待つ合図（isHomeLoaded など）と見分けるため、自分の読み込みの名前だけを見る。
    """
    if part == "State" and SHOWN.fullmatch(name):
        return f"{owner} の State で、表示中のものを Bool で持たない: {name}。シート・確認・メニューは Shown の 1 つの値で持つ"
    if (LOADED if part == "Input" else STATE_LOADED).fullmatch(name):
        return f"{owner} の {part} に、読んだ印の Bool を置かない: {name}。値と一緒に Loadable で持つ"
    if part == "State" and RUNNING.fullmatch(name):
        return f"{owner} の State に、実行中の印を手で書かない: {name}。ModelTask で持ち、isRunning で読む"
    return None


def is_flag(found):
    kind = (found.group("type") or "").strip()
    return kind in FLAG_TYPES or (found.group("value") or "").strip() in FLAG_VALUES


def swift_owner(code, start):
    """入れ子の State と Input を囲む型の名前。拡張なら拡張する型、無ければ「モデル」。"""
    for line in reversed(code[:start]):
        found = re.match(r"^(?:(?:public|package|internal|fileprivate|private)\s+)?(?:extension|(?:final\s+)?class|struct)\s+(\w+)", line)
        if found:
            return found.group(1)
    return "モデル"


def check_swift_flags(code):
    for start, end, name, indent in observable_classes(code):
        if not indent or name not in PARTS:
            continue
        owner = swift_owner(code, start)
        for index in range(start + 1, end):
            line = code[index]
            if not line.startswith(indent + "    ") or line.startswith(indent + "     "):
                continue
            found = SWIFT_FLAG.match(line.strip())
            if found and is_flag(found) and (message := flag_message(owner, name, found.group("name"))):
                yield index + 1, message


def check_kotlin_flags(code):
    owner = next((found.group(1) for line in code if (found := re.match(r"^(?:(?:public|internal|private|abstract|open|data|sealed)\s+)*class\s+(\w+)", line))), "モデル")
    for start, end, part in kotlin_parts(code):
        if part not in PARTS:
            continue
        for index in range(start + 1, end):
            found = KOTLIN_FLAG.match(code[index])
            if found and is_flag(found) and (message := flag_message(owner, part, found.group("name"))):
                yield index + 1, message
