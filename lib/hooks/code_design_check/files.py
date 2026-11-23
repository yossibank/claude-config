import functools
import os
import re

from git import git_root

LINE_LIMIT = 400
HEAD_LIMIT = 20

SWIFT_TYPE = re.compile(
    r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:(public|package|internal|fileprivate|private)\s+)?"
    r"(?:(?:final|indirect|nonisolated)\s+)*(?:struct|class|enum|actor|protocol)\s+(\w+)"
)
SWIFT_EXTENSION = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private)\s+)?extension\s+([\w.\[]+)")
KOTLIN_TYPE = re.compile(
    r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:(public|internal|private)\s+)?"
    r"(?:(?:abstract|data|enum|sealed|value|open|annotation|fun)\s+)*(?:class|interface|object)\s+(\w+)"
)
SWIFT_PROTOCOL = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:(public|package|internal|fileprivate|private)\s+)?protocol\s+(\w+)")
HIDDEN = {"private", "fileprivate"}
PARTS_DOC = "docs/architecture-parts.md"
SERIAL = re.compile(r"\d$")
WORD = re.compile(r"[A-Z]+(?![a-z])|[A-Z]?[a-z0-9]+")
FREE_NAMES = {"Package", "main"}


def is_test(path):
    folders = os.path.normpath(path).split(os.sep)[:-1]
    return any(folder == "test" or folder == "snapshots" or folder.endswith(("Test", "Tests")) for folder in folders)


@functools.cache
def root_of(folder):
    return git_root(folder)


def is_tooling(path):
    real = os.path.realpath(path)
    root = root_of(os.path.dirname(real))
    return bool(root) and os.path.relpath(real, os.path.realpath(root)).split(os.sep)[0] == ".claude"


def stem(path):
    return os.path.splitext(os.path.basename(path))[0]


def check_length(lines):
    count = len(lines) - 1 if lines and not lines[-1] else len(lines)
    if count > LINE_LIMIT:
        yield LINE_LIMIT + 1, f"1 つのファイルは {LINE_LIMIT} 行までにする（今は {count} 行）。役割ごとのファイルに分ける"


def declared(code, pattern):
    return [(index + 1, found.group(1), found.group(2)) for index, line in enumerate(code) if (found := pattern.match(line))]


def extended(code):
    return ["Array" if found.group(1).startswith("[") else found.group(1) for line in code if (found := SWIFT_EXTENSION.match(line))]


def joined_prefixes(name):
    parts = name.split(".")
    return {"".join(parts[: count + 1]) for count in range(len(parts))}


def check_swift_name(path, code):
    name = stem(path)
    types = declared(code, SWIFT_TYPE)
    extensions = extended(code)
    if name in FREE_NAMES:
        return
    if "+" in name:
        owner = name.split("+")[0]
        owners = {prefix for extension in extensions for prefix in joined_prefixes(extension)}
        if owner not in owners and all(owner != declared_name for _, _, declared_name in types):
            yield 1, f"拡張のファイルの頭は、拡張する型の名前にする: {owner}。入れ子の型は . を抜いてつなぎ、親を省かない"
    elif all(name != declared_name for _, _, declared_name in types):
        if types or set(extensions) != {"View"}:
            yield 1, f"ファイルの名前は、中の型の名前にする: {name}。拡張だけのファイルは <型>+<役割> にする"


def check_swift_types(path, code):
    owner, _, role = stem(path).partition("+")
    heads = tuple(filter(None, (owner, role)))
    for line, access, name in declared(code, SWIFT_TYPE):
        if access not in HIDDEN and not name.startswith(heads):
            yield line, f"private でない型の名前は、ファイルの名前 {owner} で始める: {name}。別のファイルに分けるか、private か入れ子にする"


def check_kotlin_types(path, code):
    words = set(WORD.findall(stem(path)))
    for line, access, name in declared(code, KOTLIN_TYPE):
        first = (WORD.findall(name) or [name])[0]
        if access != "private" and first not in words:
            yield line, f"private でない型の名前は、ファイルの名前の語で始める: {name}。別のファイルに分けるか、private にする"


def head(name):
    owner, _, role = name.partition("+")
    words = WORD.findall(role or owner)
    return words[0] if words else name


def folder_heads(folder, suffix):
    try:
        names = [stem(name) for name in os.listdir(folder) if name.endswith(suffix)]
    except OSError:
        return {}
    names = [name for name in names if not SERIAL.search(name)]
    owners = {name.partition("+")[0] for name in names}
    same_owner = len(owners) == 1 and all("+" in name for name in names)
    heads = {}
    for name in names:
        key = head(name) if same_owner else head(name.partition("+")[0])
        heads[key] = heads.get(key, 0) + 1
    return heads


def check_folder(path, suffix, seen):
    folder = os.path.dirname(path)
    if folder in seen:
        return
    seen.add(folder)
    for name, count in sorted(folder_heads(folder, suffix).items()):
        if count > HEAD_LIMIT:
            yield 1, f"このフォルダに、頭が {name} のファイルが {count} 本ある。{HEAD_LIMIT} 本を超えたら、役割の子フォルダに分ける"


def check_parts(path, code, root):
    if not root or "Shared" not in os.path.normpath(path).split(os.sep):
        return
    try:
        with open(os.path.join(root, PARTS_DOC), encoding="utf-8") as file:
            text = file.read()
    except OSError:
        return
    for line, access, name in declared(code, SWIFT_PROTOCOL):
        if access not in HIDDEN and not re.search(rf"\b{name}\b", text):
            yield line, f"Shared に置くプロトコルは、共通の部品の一覧（{PARTS_DOC}）に載せる: {name}"
