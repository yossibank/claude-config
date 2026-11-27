import functools
import os
import re

import kotlin_source
import swift_source
from hooks.code_design_check.effect import is_screen, read
from hooks.code_design_check.flags import swift_owner
from hooks.code_design_check.modules import module_of, sources
from hooks.code_design_check.state import block_end, kotlin_parts, next_code, observable_classes
from hooks.code_design_check.view import COMPOSABLE

SLOTS = {
    "fields": "Fields",
    "presented": "Presented",
    "notices": "Notices",
    "task": "ModelTask",
    "outcome": "ScreenOutcome",
    "submodels": "Submodels",
}
SCREEN_SLOTS = ("fields", "presented")
ATTRIBUTES = r"(?:@\w+(?:\([^)]*\))?\s+)*"
SWIFT_MEMBER = re.compile(
    "^" + ATTRIBUTES + r"(?P<access>(?:(?:public|package|internal|fileprivate|private|open|nonisolated|static|lazy|weak)(?:\(set\))?\s+)*)"
    r"(?P<word>var|let)\s+(?P<name>\w+)\s*(?::\s*(?P<type>[^={]+?))?\s*(?:=\s*(?P<value>[^{]*?))?\s*(?P<open>\{)?\s*$"
)
SWIFT_CLOSED = re.compile(r"\b(?:internal|fileprivate|private)\(set\)")
SWIFT_OBSERVER = re.compile(r"^\s*(?:didSet|willSet)\b")
SWIFT_CALL = re.compile(r"^((?:\w+\.)*[A-Z]\w*(?:<.*>)?)(?:\.init)?\(")
SWIFT_FIELDS = re.compile(r"^(\s*)" + ATTRIBUTES + r"(?:(?:public|package|internal|fileprivate|private)\s+)?struct\s+Fields\b")
MARK = re.compile(r"\bScreenEditable\b")
SWIFT_FIELDS_EXTENSION = re.compile(r"^(\s*)" + ATTRIBUTES + r"(?:(?:public|package|internal|fileprivate|private)\s+)?extension\s+(?:\w+\.)*Fields\b")
KOTLIN_MEMBER = re.compile(
    r"^        (?P<access>(?:(?:public|internal|private|protected|override|open|lateinit)\s+)*)(?P<word>va[lr])\s+(?P<name>\w+)"
    r"\s*(?::\s*(?P<type>.+?))?\s*(?P<rest>(?:=|\bby\b).*)?$"
)
KOTLIN_DELEGATE = re.compile(r"^by\s+mutable(?P<kind>\w*)StateOf(?:<(?P<generic>[^(]*)>)?\((?P<value>.*?)(?P<close>\))?\s*$")
KOTLIN_PRIVATE_SET = re.compile(r"^\s*private\s+set\b")
KOTLIN_CALL = re.compile(r"^((?:\w+\.)*[A-Z]\w*(?:<.*>)?)\(")
KOTLIN_KINDS = {"Int": "Int", "Long": "Long", "Float": "Float", "Double": "Double"}
KOTLIN_CLASS = re.compile(r"^(?:(?:public|internal|private|abstract|open|data|sealed)\s+)*class\s+(\w+)")
KOTLIN_FIELDS = re.compile(r"^(\s*)(?:(?:public|internal|private)\s+)?data\s+class\s+Fields\s*\(")
KOTLIN_PARAMETER = re.compile(r"\b(?:val|var)\s+(\w+)\s*:")
FIELDS_READ = re.compile(r"\bfields[?!]?\.(\w+)")


def swift_kind(kind, value):
    """書かれた型か、初めの値の呼び出しの名前で型を読む。読めない時は None を返す。"""
    if kind:
        return kind.strip()
    found = SWIFT_CALL.match((value or "").strip())
    return found.group(1) if found else None


def kotlin_kind(kind, rest, code, index):
    """書かれた型か、初めの値（mutableStateOf の中身を含む）の呼び出しの名前で型を読む。読めない時は None を返す。"""
    if kind:
        return kind.strip().rstrip(",").strip()
    rest = (rest or "").strip().rstrip(",")
    if rest.startswith("="):
        value = rest[1:].strip()
    elif found := KOTLIN_DELEGATE.match(rest):
        if found.group("kind") in KOTLIN_KINDS:
            return KOTLIN_KINDS[found.group("kind")]
        if found.group("generic"):
            return found.group("generic").strip()
        value = found.group("value") if found.group("close") else next_code(code, index).strip()
    else:
        return None
    found = KOTLIN_CALL.match(value)
    return found.group(1) if found else None


def type_name(kind):
    """型の頭の名前。Optional と配列と組は、そのままの書き方を返す。"""
    kind = kind.strip()
    if kind.endswith(("?", "!")) or kind.startswith(("[", "(")):
        return kind
    found = re.match(r"(?:\w+\.)*(\w+)\s*(?:<.*>)?$", kind)
    return found.group(1) if found else kind


def wrong_slot(owner, name, kind):
    """枠の名前の値が、決まりの型でなければ文を返す。"""
    expected = SLOTS.get(name)
    if not expected or not kind or type_name(kind) == expected:
        return None
    return f"{owner} の State の枠 {name} は {expected} の型にする（今は {kind}）。枠の名前は、決まった型の値だけに使う"


def swift_members(code, start, end, indent):
    for index in range(start + 1, end):
        line = code[index]
        if not line.startswith(indent + "    ") or line.startswith(indent + "     "):
            continue
        found = SWIFT_MEMBER.match(line.strip())
        if not found or "static" in found.group("access").split():
            continue
        if found.group("open") and not SWIFT_OBSERVER.match(next_code(code, index)):
            continue
        yield index, found


def check_swift_slots(code):
    """入れ子の State の直下を見る。画面が書ける public var は fields と presented だけにし、枠の名前は決まった型に使う。"""
    for start, end, part, indent in observable_classes(code):
        if not indent or part != "State":
            continue
        owner = swift_owner(code, start)
        for index, found in swift_members(code, start, end, indent):
            name, access = found.group("name"), found.group("access")
            if found.group("word") == "var" and "public" in access.split() and not SWIFT_CLOSED.search(access) and name not in SCREEN_SLOTS:
                yield index + 1, f"{owner} の State で、画面が書く public var は fields と presented だけにする: {name}。ほかは public let か public internal(set) にして、モデルが書く"
            if message := wrong_slot(owner, name, swift_kind(found.group("type"), found.group("value"))):
                yield index + 1, message


def kotlin_owner(code):
    return next((found.group(1) for line in code if (found := KOTLIN_CLASS.match(line))), "モデル")


def declaration_end(code, index, end):
    """複数行の mutableStateOf の初めの値は、閉じかっこの行までを宣言と見る。"""
    if code[index].rstrip().endswith("("):
        return next((at for at in range(index + 1, end) if code[at].startswith("        )")), index)
    return index


def check_kotlin_slots(code):
    """入れ子の class State の直下を見る。var は private set にし、枠の名前は決まった型に使う。"""
    owner = kotlin_owner(code)
    for start, end, part in kotlin_parts(code):
        if part != "State":
            continue
        for index in range(start + 1, end):
            found = KOTLIN_MEMBER.match(code[index])
            if not found:
                continue
            name = found.group("name")
            closed = "private" in found.group("access").split() or KOTLIN_PRIVATE_SET.match(next_code(code, declaration_end(code, index, end)))
            if found.group("word") == "var" and not closed:
                yield index + 1, f"{owner} の State の var は private set にする: {name}。画面が書く値は、State の関数（updateFields・present など）を通す"
            if message := wrong_slot(owner, name, kotlin_kind(found.group("type"), found.group("rest"), code, index)):
                yield index + 1, message


def swift_fields(code):
    """struct Fields の宣言の行と、直下の保存プロパティの名前と行を返す。"""
    for index, line in enumerate(code):
        found = SWIFT_FIELDS.match(line)
        if not found or not line.rstrip().endswith("{") or not MARK.search(line):
            continue
        end = block_end(code, index, found.group(1))
        yield index, [(at, member.group("name")) for at, member in swift_members(code, index, end, found.group(1))]


def kotlin_fields(code):
    """data class Fields の宣言の行と、引数の val と var の名前と行を返す。"""
    for index, line in enumerate(code):
        found = KOTLIN_FIELDS.match(line)
        if not found:
            continue
        if line.rstrip().endswith("("):
            end = next((at for at in range(index + 1, len(code)) if code[at].startswith(found.group(1) + ")")), index)
            members = [(at, member.group(1)) for at in range(index + 1, end) if (member := KOTLIN_PARAMETER.search(code[at]))]
        else:
            end = index
            members = [(index, name) for name in KOTLIN_PARAMETER.findall(line)]
        if MARK.search(code[end]):
            yield index, members


def own_uses(code):
    """Fields の拡張と、Fields の中の計算プロパティと関数で使う語。Fields が自分で読む値は、モデルが読んでいると見る。"""
    words = set()
    for index, line in enumerate(code):
        found = SWIFT_FIELDS_EXTENSION.match(line) or SWIFT_FIELDS.match(line)
        if found and line.rstrip().endswith("{"):
            end = block_end(code, index, found.group(1))
            stored = {at for at, _ in swift_members(code, index, end, found.group(1))}
            words |= {word for at in range(index + 1, end) if at not in stored for word in re.findall(r"\w+", code[at])}
    return words


@functools.cache
def model_reads(folder, suffix):
    """フォルダの下の、画面でないファイルが fields.<名前> で読む名前と、Fields が自分で使う語を返す。"""
    reads = set()
    for path in sources(folder, suffix):
        text = read(path)
        if "fields" not in text and "Fields" not in text:
            continue
        if suffix == ".swift":
            code = swift_source.mask(text)
            if is_screen(path, code):
                continue
            reads |= own_uses(code)
        else:
            code = kotlin_source.mask(text)
            if any(COMPOSABLE.search(line) for line in code):
                continue
        reads |= {name for line in code for name in FIELDS_READ.findall(line)}
    return frozenset(reads)


def check_unread_fields(path, code):
    """fields の値のうち、同じモジュールの画面でないファイルが fields.<名前> で読まない物を返す。"""
    suffix = os.path.splitext(path)[1]
    declared = list(swift_fields(code) if suffix == ".swift" else kotlin_fields(code))
    if not any(members for _, members in declared):
        return
    reads = model_reads(module_of(path) or os.path.dirname(os.path.realpath(path)), suffix)
    for _, members in declared:
        for index, name in members:
            if name not in reads:
                yield index + 1, f"Fields の {name} を、モデルのファイルが fields.{name} として読んでいない。fields には、モデルが読む入力と選んでいる物だけを置く。表示中のものは presented に置く"
