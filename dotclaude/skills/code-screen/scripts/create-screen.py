import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "..", "lib"))

from script_io import Failure, fail, run_main  # noqa: E402

USAGE = "使い方: create-screen.py <swift|kotlin> <list|edit|base> <モデルのフォルダ> <画面のフォルダ> <テストのフォルダ> [<名前>=<値>...]"
TEMPLATES = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "templates")
SUFFIXES = {"swift": ".swift", "kotlin": ".kt"}
KINDS = ("list", "edit", "base")
ROLES = ("model", "view", "test")
SKIPPED = {".git", ".build", ".gradle", "build", "DerivedData", "node_modules", "Pods"}
TOKEN = re.compile(r"__[A-Za-z]+__")
NAME = re.compile(r"[A-Z][A-Za-z0-9]*")
WORD = re.compile(r"[A-Za-z][A-Za-z0-9]*")
SWIFT_TARGET = re.compile(r"/(?:Sources|Tests)/([^/]+)")
KOTLIN_SOURCE = re.compile(r"/src/[^/]+/(?:kotlin|java)/(.+)$")
KOTLIN_PACKAGE = re.compile(r"^package\s+([\w.]+)", re.M)
IMPORT = re.compile(r"^(?:@testable )?import ")
KOTLIN_LAST = ("java.", "javax.", "kotlin.")
PARTS = ("ScreenEditable", "Shown", "ModelTask", "Loadable", "ScreenWait", "ErrorNotice")
BASE = {
    "swift": ("ScreenParts", "ScreenClock", "ScreenPerforming", "ScreenOutcome", "onOutcome", *PARTS),
    "kotlin": ("ScreenClock", "ScreenPerforming", "ScreenOutcome", "OnOutcome", *PARTS),
}
RENAMED = {
    "swift": (*BASE["swift"], "AppDatabase", "Core", "Store"),
    "kotlin": (*BASE["kotlin"], "AppDatabase"),
}
ASKED = ("Screen", "Item", "View", "Database")
CALLS = ("async", "sync")
UNUSED = {"async": (), "sync": ("ScreenPerforming", "ModelTask", "Loadable")}
BASE_HINT = "先に、形を base にして土台を足す。名前が違う時は、<既定の名前>=<アプリの名前> で渡す"


def declared(name):
    kinds = r"(?:struct|class|protocol|interface|object|enum|actor|typealias)"
    return re.compile(rf"\b{kinds}\s+{name}\b|\bfunc?\s+(?:<[^>]*>\s*)?(?:[\w.]+\.)?{name}\s*[(<]")


def repository(folder):
    path = Path(folder).resolve()
    for parent in (path, *path.parents):
        if (parent / ".git").exists():
            return str(parent)
    return ""


def sources(root, suffix):
    for directory, folders, files in os.walk(root):
        folders[:] = sorted(folder for folder in folders if folder not in SKIPPED)
        for file in sorted(files):
            if file.endswith(suffix):
                yield os.path.join(directory, file)


def find(names, root, suffix):
    """名前を宣言しているファイルを、名前ごとに返す。"""
    patterns = {name: declared(name) for name in names}
    found = {}
    for path in sources(root, suffix):
        try:
            text = Path(path).read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for name, pattern in patterns.items():
            if name not in found and pattern.search(text):
                found[name] = (path, text)
    return found


def swift_target(folder):
    found = SWIFT_TARGET.search(os.path.abspath(folder) + "/")
    if not found:
        raise Failure(f"フォルダが Sources/<ターゲット> か Tests/<ターゲット> の下に無い: {folder}")
    return found.group(1)


def kotlin_package(folder):
    found = KOTLIN_SOURCE.search(os.path.abspath(folder))
    if not found:
        raise Failure(f"フォルダが src/<種類>/kotlin/<パッケージ> の下に無い: {folder}")
    return found.group(1).strip("/").replace("/", ".")


def package_in(found, name, hint):
    if name not in found:
        raise Failure(f"型か関数が無い: {name}。{hint}")
    package = KOTLIN_PACKAGE.search(found[name][1])
    if not package:
        raise Failure(f"package の行が無い: {found[name][0]}")
    return package.group(1)


def lower_first(name):
    return name[:1].lower() + name[1:]


def parse(pairs, language, kind):
    given = {}
    for pair in pairs:
        name, mark, value = pair.partition("=")
        if not mark or not WORD.fullmatch(value):
            raise Failure(f"<名前>=<値> の形で、値は英数字で書く: {pair}")
        if name not in ASKED + RENAMED[language]:
            raise Failure(f"知らない名前: {name}。使えるのは {'・'.join(ASKED + RENAMED[language])}")
        given[name] = value
    asked = {name: given.pop(name) for name in ASKED if name in given}
    if kind != "base":
        for name in ("Screen", "Item"):
            if not NAME.fullmatch(asked.get(name, "")):
                raise Failure(f"{name}=<頭が大文字の名前> が要る")
    return asked, given, calls_of(asked.pop("Database", CALLS[0]), language, kind)


def calls_of(calls, language, kind):
    """DB の呼び方を確かめて返す。同期の版は、Swift の画面にだけある。"""
    if calls not in CALLS:
        raise Failure(f"Database= は {'・'.join(CALLS)} のどちらかにする: {calls}")
    if calls != CALLS[0] and (language != "swift" or kind == "base"):
        raise Failure(f"Database={calls} の版は、Swift の list と edit にだけある")
    return calls


def tokens_of(language, kind, asked, renames, folders, root, calls):
    tokens = {}
    if kind != "base":
        screen, item = asked["Screen"], asked["Item"]
        tokens |= {"__Screen__": screen, "__View__": asked.get("View", f"{screen}View"), "__Item__": item, "__item__": lower_first(item)}
    base = [renames.get(name, name) for name in BASE[language] if name not in UNUSED[calls]]
    found = find(base, root, SUFFIXES[language])
    if kind == "base":
        if len(found) == len(base):
            raise Failure(f"土台の型が既にある: {'・'.join(sorted(found))}")
    else:
        missing = [name for name in base if name not in found]
        if missing:
            raise Failure(f"土台の型か関数が無い: {'・'.join(missing)}。{BASE_HINT}")
    if language == "swift":
        tokens["__Models__"] = swift_target(folders["model"])
        return tokens
    tokens |= {f"__{role}Package__": kotlin_package(folders[role]) for role in ROLES}
    if kind == "base":
        return tokens
    performing, outcome, database = (renames.get(name, name) for name in ("ScreenPerforming", "OnOutcome", "AppDatabase"))
    item = asked["Item"]
    types = find([database, item, f"{item}Draft"], root, ".kt")
    hint = "先に、Core と Store に足す"
    tokens |= {
        "__base__": package_in(found, performing, BASE_HINT),
        "__viewBase__": package_in(found, outcome, BASE_HINT),
        "__store__": package_in(types, database, hint),
        "__core__": package_in(types, item, hint),
        "__draft__": package_in(types, f"{item}Draft", hint),
    }
    return tokens


def import_key(language, line):
    name = IMPORT.sub("", line)
    if language == "swift":
        return (0, name.lower())
    return (next((rank for rank, head in enumerate(KOTLIN_LAST, 1) if name.startswith(head)), 0), name)


def tidy_imports(language, text, own):
    """自分のモジュールの import を落とし、重なりを除いて並べ直す。"""
    lines = text.split("\n")
    rows = [index for index, line in enumerate(lines) if IMPORT.match(line)]
    if not rows:
        return text
    kept = {line for line in (lines[index] for index in rows) if not is_own(language, IMPORT.sub("", line), own)}
    ordered = sorted(kept, key=lambda line: import_key(language, line))
    return "\n".join(lines[: rows[0]] + ordered + lines[rows[-1] + 1 :])


def is_own(language, name, own):
    if language == "swift":
        return name == own
    package, _, _ = name.rpartition(".")
    return package == own


def render(text, tokens, renames):
    for token, value in tokens.items():
        text = text.replace(token, value)
    for old, new in renames.items():
        text = re.sub(rf"\b{old}\b", new, text)
    return text


def own_of(language, folder):
    return swift_target(folder) if language == "swift" else kotlin_package(folder)


def is_present(language, text, present):
    """土台のひな形が宣言する名前が、どれもリポジトリにあるか。"""
    names = [name for name in BASE[language] if declared(name).search(text)]
    return bool(names) and all(name in present for name in names)


def plan(language, kind, folders, tokens, renames, present):
    source = Path(TEMPLATES) / language / kind
    placed = set()
    for role in ROLES:
        for template in sorted((source / role).glob("*")):
            target = os.path.join(folders[role], render(template.name, tokens, renames))
            text = render(template.read_text(encoding="utf-8"), tokens, renames)
            if kind == "base" and is_present(language, template.read_text(encoding="utf-8"), present):
                continue
            if os.path.lexists(target) or target in placed:
                raise Failure(f"ファイルが既にある: {target}")
            placed.add(target)
            left = sorted(set(TOKEN.findall(text + os.path.basename(target))))
            if left:
                raise Failure(f"置き換えていない印がある: {'・'.join(left)}（{template.name}）")
            yield target, tidy_imports(language, text, own_of(language, folders[role]))


def main():
    if len(sys.argv) < 6:
        fail(USAGE)
    language, kind = sys.argv[1:3]
    if language not in SUFFIXES or kind not in KINDS:
        fail(USAGE)
    folders = dict(zip(ROLES, map(os.path.abspath, sys.argv[3:6])))
    asked, renames, calls = parse(sys.argv[6:], language, kind)
    root = repository(folders["model"]) or os.path.commonpath(list(folders.values()))
    tokens = tokens_of(language, kind, asked, renames, folders, root, calls)
    template = kind if calls == CALLS[0] else f"{kind}-{calls}"
    present = set(find([renames.get(name, name) for name in BASE[language]], root, SUFFIXES[language])) if kind == "base" else set()
    present = {name for name in BASE[language] if renames.get(name, name) in present}
    files = list(plan(language, template, folders, tokens, renames, present))
    for target, text in files:
        os.makedirs(os.path.dirname(target), exist_ok=True)
        Path(target).write_text(text, encoding="utf-8")
        print(f"OK {target}")


if __name__ == "__main__":
    run_main(main)
