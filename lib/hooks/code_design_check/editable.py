import os
import re

from hooks.code_design_check.flags import swift_owner
from hooks.code_design_check.state import kotlin_parts, next_code, observable_classes

MARK = "ScreenEditable"
SWIFT_HEAD = re.compile(r"\b(?:struct|class|enum|actor|protocol|extension)\s+(?:\w+\.)*(\w+)")
KOTLIN_HEAD = re.compile(r"\b(?:class|interface|object)\s+(\w+)")
SWIFT_NAMED = re.compile(r"\b(?:struct|class|enum|actor|protocol|typealias)\s+(\w+)")
KOTLIN_NAMED = re.compile(r"\b(?:class|interface|object|typealias)\s+(\w+)")
KEYWORDS = {"func", "var", "let", "fun", "val", "init", "subscript"}
SWIFT_OPEN_VAR = re.compile(
    r"^(?:@\w+(?:\([^)]*\))?\s+)*(?P<access>(?:(?:public|package|internal|fileprivate|private|open)(?:\(set\))?\s+)*)"
    r"var\s+(?P<name>\w+)\s*(?::\s*(?P<type>[^={]+?))?\s*(?:=\s*(?P<value>[^{]*?))?\s*(?P<open>\{)?\s*$"
)
SWIFT_CLOSED = re.compile(r"\b(?:internal|fileprivate|private)\(set\)")
SWIFT_OBSERVER = re.compile(r"^\s*(?:didSet|willSet)\b")
KOTLIN_VAR = re.compile(
    r"^        (?P<access>(?:(?:public|internal|private|protected|override)\s+)*)var\s+(?P<name>\w+)\s*(?::\s*(?P<type>[^=]+?))?"
    r"\s+by\s+mutable(?P<kind>\w*)StateOf(?:<(?P<generic>[^(]*)>)?\((?P<value>.*?)(?P<close>\))?\s*$"
)
KOTLIN_CLOSED_SET = re.compile(r"^\s*(?:private|internal|protected)\s+set\b")
KOTLIN_KINDS = {"Int": "Int", "Long": "Long", "Float": "Float", "Double": "Double", "List": "List", "Map": "Map"}
SWIFT_PLAIN = {
    "Bool", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "Double", "Float", "CGFloat",
    "String", "Character", "Substring", "Array", "Dictionary", "Set", "Optional", "Date", "UUID", "URL", "Data", "Decimal",
    "TimeInterval", "Result", "Task", "Tuple",
}
SWIFT_WRAPPERS = {"Optional", "Array", "Dictionary", "Set"}
KOTLIN_PLAIN = {
    "Boolean", "Int", "Long", "Short", "Byte", "Float", "Double", "Char", "String", "List", "MutableList", "Map", "MutableMap",
    "Set", "MutableSet", "Array", "Pair", "Triple", "Optional", "Tuple",
}
SWIFT_CALL = re.compile(r"^((?:\w+\.)*[A-Z]\w*(?:<.*>)?)(?:\.init)?\(")
KOTLIN_CALL = re.compile(r"^((?:\w+\.)*[A-Z]\w*(?:<.*>)?)\(")
KOTLIN_COLLECTION = re.compile(r"^(?:empty|mutable|(?=[lms]))(?P<kind>[Ll]ist|[Mm]ap|[Ss]et)(?:Of)?(?:<.*>)?\(")


def skip_group(text, at, opening, closing):
    depth = 0
    while at < len(text):
        depth += (text[at] == opening) - (text[at] == closing)
        at += 1
        if depth == 0:
            break
    return at


def supertypes(text, at):
    """型の宣言の名前の後ろから、継承と適合の型の名前と、where で条件が付くかを返す。ジェネリクスと Kotlin の引数の並びは飛ばす。"""
    for opening, closing in (("<", ">"), ("(", ")")):
        while at < len(text) and text[at] in " \t\n":
            at += 1
        if at < len(text) and text[at] == opening:
            at = skip_group(text, at, opening, closing)
    while at < len(text) and text[at] in " \t\n":
        at += 1
    if at >= len(text) or text[at] != ":":
        return set(), False
    clause = re.split(r"\{|\n\s*\n", text[at + 1 :], maxsplit=1)[0]
    where = re.search(r"\bwhere\b", clause)
    clause = clause[: where.start()] if where else clause
    clause = re.sub(r"<[^<>]*>|\([^()]*\)", "", re.sub(r"<[^<>]*>", "", clause))
    return {found.group(1) for item in clause.split(",") if (found := re.match(r"\s*(?:\w+\.)*(\w+)", item))}, bool(where)


def top_split(text):
    parts, depth, begin = [], 0, 0
    for at, char in enumerate(text):
        depth += (char in "<[(") - (char in ">])")
        if char in ",:" and depth == 0:
            parts.append(text[begin:at])
            begin = at + 1
    return [part.strip() for part in [*parts, text[begin:]] if part.strip()]


def parse(kind):
    """型の書き方を、名前と型の引数に分ける。"""
    kind = kind.strip()
    if kind.endswith(("?", "!")):
        return "Optional", [kind[:-1]]
    if kind.startswith("[") and kind.endswith("]"):
        inner = top_split(kind[1:-1])
        return ("Dictionary" if len(inner) == 2 else "Array"), inner
    if kind.startswith("("):
        return "Tuple", []
    found = re.match(r"(?:\w+\.)*(\w+)\s*(?:<(.*)>)?", kind)
    if not found:
        return None, []
    return found.group(1), top_split(found.group(2) or "")


class Editable:
    """渡されたファイルとその隣のファイルから、型の宣言と ScreenEditable への適合を集める。"""

    def __init__(self, paths, suffix, mask, heads, named, plain, wrappers=frozenset()):
        self.paths, self.suffix, self.mask, self.heads, self.named, self.plain = paths, suffix, mask, heads, named, plain
        self.wrappers = wrappers
        self.declared = None
        self.marked = {}

    def load(self):
        folders = {os.path.dirname(os.path.abspath(path)) for path in self.paths}
        files = {os.path.abspath(path) for path in self.paths}
        for folder in folders:
            try:
                files |= {os.path.join(folder, name) for name in os.listdir(folder) if name.endswith(self.suffix)}
            except OSError:
                continue
        self.declared = set()
        parents = []
        for path in files:
            try:
                with open(path, encoding="utf-8") as file:
                    text = "\n".join(self.mask(file.read()))
            except (OSError, UnicodeDecodeError):
                continue
            self.declared |= {name for name in self.named.findall(text) if name not in KEYWORDS}
            parents += [(found.group(1), *supertypes(text, found.end())) for found in self.heads.finditer(text) if found.group(1) not in KEYWORDS]
        self.marked = {MARK: False}
        grown = True
        while grown:
            grown = False
            for name, above, conditional in parents:
                if above & self.marked.keys() and self.marked.get(name, True) and (name not in self.marked or not conditional):
                    self.marked[name] = conditional
                    grown = True

    def verdict(self, kind):
        """型が ScreenEditable でないと分かれば True。宣言が見つからない型は、分からないので False にする。

        where で条件の付く適合（extension Optional: ScreenEditable where Wrapped: ScreenEditable など）は、型の引数で決める。
        Swift の Optional・Array・Dictionary・Set は、適合の拡張が集めた範囲の外にあるかもしれないので、いつも型の引数で決める。
        """
        if self.declared is None:
            self.load()
        name, arguments = parse(kind)
        if name is None:
            return False
        if self.marked.get(name) is False:
            return False
        if name in self.marked or name in self.wrappers:
            return any(self.verdict(argument) for argument in arguments)
        return name in self.plain or name in self.declared


def swift_kind(kind, value):
    if kind:
        return kind.strip()
    value = (value or "").strip()
    if value in {"true", "false"}:
        return "Bool"
    if value.startswith('"'):
        return "String"
    if re.fullmatch(r"-?\d+", value):
        return "Int"
    if re.fullmatch(r"-?\d+\.\d+", value):
        return "Double"
    found = SWIFT_CALL.match(value)
    return found.group(1) if found else None


def kotlin_kind(kind, generic, state, value):
    if state in KOTLIN_KINDS:
        return KOTLIN_KINDS[state]
    kind = (kind or generic or "").strip()
    if kind:
        return kind
    value = value.strip()
    if value in {"true", "false"}:
        return "Boolean"
    if value.startswith('"'):
        return "String"
    if re.fullmatch(r"-?\d+", value):
        return "Int"
    if re.fullmatch(r"-?\d+L", value):
        return "Long"
    if re.fullmatch(r"-?\d+(?:\.\d+)?[fF]", value):
        return "Float"
    if re.fullmatch(r"-?\d+\.\d+", value):
        return "Double"
    if found := KOTLIN_COLLECTION.match(value):
        return found.group("kind").title()
    found = KOTLIN_CALL.match(value)
    return found.group(1) if found else None


def written(owner, name, kind, closing):
    return f"{owner} の State で、画面が書ける値は ScreenEditable の型だけにする: {name}（{kind}）。ほかの値は {closing} にして、State の関数で書く"


def check_swift_writes(code, editable):
    for start, end, part, indent in observable_classes(code):
        if not indent or part != "State":
            continue
        owner = swift_owner(code, start)
        for index in range(start + 1, end):
            line = code[index]
            if not line.startswith(indent + "    ") or line.startswith(indent + "     "):
                continue
            found = SWIFT_OPEN_VAR.match(line.strip())
            if not found or "public" not in found.group("access").split() or SWIFT_CLOSED.search(found.group("access")):
                continue
            if found.group("open") and not SWIFT_OBSERVER.match(next_code(code, index)):
                continue
            kind = swift_kind(found.group("type"), found.group("value"))
            if kind and editable.verdict(kind):
                yield index + 1, written(owner, found.group("name"), kind, "internal(set)")


def check_kotlin_writes(code, editable):
    owner = next((found.group(1) for line in code if (found := re.match(r"^(?:(?:public|internal|private|abstract|open|data|sealed)\s+)*class\s+(\w+)", line))), "モデル")
    for start, end, part in kotlin_parts(code):
        if part != "State":
            continue
        for index in range(start + 1, end):
            found = KOTLIN_VAR.match(code[index])
            if not found or re.search(r"\b(?:private|internal|protected)\b", found.group("access")):
                continue
            value, last = found.group("value"), index
            if not found.group("close"):
                last = next((at for at in range(index + 1, end) if code[at].startswith("        )")), index)
                value = next_code(code, index).strip()
            if KOTLIN_CLOSED_SET.match(next_code(code, last)):
                continue
            kind = kotlin_kind(found.group("type"), found.group("generic"), found.group("kind"), value)
            if kind and editable.verdict(kind):
                yield index + 1, written(owner, found.group("name"), kind, "private set")


def swift_editable(paths, mask):
    return Editable(paths, ".swift", mask, SWIFT_HEAD, SWIFT_NAMED, SWIFT_PLAIN, SWIFT_WRAPPERS)


def kotlin_editable(paths, mask):
    return Editable(paths, ".kt", mask, KOTLIN_HEAD, KOTLIN_NAMED, KOTLIN_PLAIN)
