import functools
import os
import re

from git import git

COMMON_DOC = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "docs", "app", "ios-naming.md")
APP_DOC = os.path.join("docs", "architecture-naming.md")
ROLE_WORD = re.compile(r"^\|\s*`\+(\w+)`", re.M)
VERSION = re.compile(r"^V\d+(?:_\d+)*$")
IMPORT = re.compile(r"^import\s+(\w+)")
TYPE = re.compile(
    r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:(public|package|internal|fileprivate|private)\s+)?"
    r"(?:(?:final|indirect|nonisolated)\s+)*(struct|class|enum|actor)\s+(\w+)([^{]*)"
)
OBSERVABLE = re.compile(r"@Observable\b")
EXTENSION = re.compile(r"^(?:(?:public|package|internal|fileprivate|private)\s+)?extension\s+(\w+)\s*:")
VIEW_SUFFIXES = ("View", "Sheet", "Card", "Row", "Tile", "Banner", "Drawer")
VIEW_ROLES = re.compile(r"\b(?:View|ViewModifier|Shape|Layout|ButtonStyle|UIViewRepresentable|PreviewProvider)\b")
MODEL_SUFFIXES = ("Model", "Flow", "Drag")
SCREEN_MODULES = ("FeatureModels", "Features", "AppFeature")
WORD = re.compile(r"[A-Z]+(?![a-z])|[A-Z]?[a-z0-9]+")
DECLARED = re.compile(r"\b(?:func|var|let|case|struct|class|enum|actor|protocol|typealias)\s+`?(\w+)")
ENDINGS = ("ing", "ion", "es", "s")
STEM_MIN = 3


def words_in(path):
    try:
        with open(path, encoding="utf-8") as file:
            return set(ROLE_WORD.findall(file.read()))
    except OSError:
        return set()


@functools.cache
def listed_words(root):
    return words_in(COMMON_DOC) | words_in(os.path.join(root, APP_DOC))


@functools.cache
def stems(root):
    result = git(root, "ls-files", "--cached", "--others", "--exclude-standard", "*.swift")
    lines = result.stdout.splitlines() if result and result.returncode == 0 else []
    names = [os.path.splitext(os.path.basename(line))[0] for line in lines]
    return tuple(names)


@functools.cache
def role_counts(root):
    counts = {}
    for name in stems(root):
        role = name.partition("+")[2]
        if role:
            counts[role] = counts.get(role, 0) + 1
    return counts


def stems_of(role):
    words = [word.lower() for word in WORD.findall(role)]
    return [next((word[: -len(end)] for end in ENDINGS if word.endswith(end) and len(word) - len(end) >= STEM_MIN), word) for word in words]


def adds(code, role):
    declared = [found.group(1).lower() for line in code for found in DECLARED.finditer(line)]
    return any(stem in name for stem in stems_of(role) for name in declared)


def names_type(root, role):
    names = set(stems(root))
    return role in names or (role.endswith("Query") and role[: -len("Query")] in names)


def check_swift_role(path, code, root):
    name = os.path.splitext(os.path.basename(path))[0]
    role = name.partition("+")[2]
    if not role or not root:
        return
    imports = {found.group(1) for line in code if (found := IMPORT.match(line))}
    known = (
        role in listed_words(root)
        or VERSION.match(role)
        or role in imports
        or adds(code, role)
        or names_type(root, role)
        or role_counts(root).get(role, 0) > 1
    )
    if not known:
        yield 1, f"拡張の役割の語は、足す物の名前か、名前の文書の表の語にする: +{role}"


def module_of(path):
    parts = os.path.normpath(path).split(os.sep)
    return parts[parts.index("Sources") + 1] if "Sources" in parts[:-1] else ""


def header_of(code, index):
    parts = []
    for line in code[index:]:
        parts.append(line.split("{")[0])
        if "{" in line:
            break
    return " ".join(parts)


def attributes_of(code, index):
    back = index
    while back > 0 and code[back - 1].strip().startswith("@"):
        back -= 1
    return code[back : index + 1]


def viewed_names(code):
    found = ((index, EXTENSION.match(line)) for index, line in enumerate(code))
    return {match.group(1) for index, match in found if match and VIEW_ROLES.search(header_of(code, index)[match.end() :])}


def check_swift_suffix(path, code):
    if module_of(path) not in SCREEN_MODULES:
        return
    viewed = viewed_names(code)
    for index, line in enumerate(code):
        found = TYPE.match(line)
        if not found or found.group(1) in ("private", "fileprivate"):
            continue
        kind, name = found.group(2), found.group(3)
        conformances = header_of(code, index)[found.end(3) :]
        observable = any(OBSERVABLE.search(text) for text in attributes_of(code, index))
        suffix = next((end for end in MODEL_SUFFIXES if name.endswith(end)), None)
        if suffix and not (kind == "class" and observable):
            yield index + 1, f"語尾の {suffix} は、@Observable のクラスだけに付ける: {name}"
        elif name.endswith(VIEW_SUFFIXES) and not (VIEW_ROLES.search(conformances) or name in viewed):
            yield index + 1, f"画面の部品の語尾は、View に適合する型だけに付ける: {name}"
