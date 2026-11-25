import functools
import os
import re

import swift_source
from hooks.code_design_check.modules import module_holds, sources, swift_module
from hooks.code_design_check.state import block_end, observable_classes
from hooks.code_design_check.view import ATTRIBUTES, COMPOSABLE, SWIFT_ACCESS, is_part_library, top_lines

MODEL_PARTS = ("state", "input", "dependencies")
OBSERVABLE = "@Observable"
EXTENDED_VIEW = "View"
SWIFT_HEAD = r"^(\s*)" + ATTRIBUTES + SWIFT_ACCESS + r"(?:final\s+)?"
SWIFT_SCREEN = re.compile(SWIFT_HEAD + r"(?P<word>struct|class|extension)\s+(?P<name>[\w.]+)(?:<[^>]*>)?\s*:[^{]*\b(?:View|ViewModifier)\b")
SWIFT_EXTENSION = re.compile(SWIFT_HEAD + r"extension\s+(?P<name>[\w.]+)")
SWIFT_TASK = re.compile(r"(?<![\w.])Task\s*(?P<generic><[^<>{(=]*>\s*)?(?:[{(]|\.(?:detached|init)\b)")
SWIFT_KIND = re.compile(r"(?:->|:)\s*$")
SWIFT_KEPT = re.compile(r"^\s*(?:@ObservationIgnored\s+)?" + SWIFT_ACCESS + r"var\s+(\w+)\s*:\s*Task<[^=]*>\?\s*(?:=\s*nil\s*)?$")
SWIFT_ASSIGNED = re.compile(r"^\s*(?:self\.)?(\w+)\s*=\s*$")
SWIFT_EFFECT = "画面で Task を始めない。モデルの口から始め、結果は state の変化で受ける。画面だけの非同期は、View でない型が Task? の保存プロパティに入れて取り消す"
KOTLIN_SCOPE = re.compile(r"\b(?:rememberCoroutineScope|CoroutineScope|MainScope)(?=\s*\()|(?<![\w.])GlobalScope\b")
KOTLIN_START = re.compile(r"\.\s*(launch|async)\s*(?:\((?:[^()]|\([^()]*\))*\)\s*)?\{")
KOTLIN_EFFECT = "画面でコルーチンを始めない（{}）。モデルの口から始め、結果は State の変化で受ける。画面の寿命の読み込みは、LaunchedEffect からモデルの関数を呼ぶ"


def task_starts(code):
    for index, line in enumerate(code):
        for found in SWIFT_TASK.finditer(line):
            before = line[: found.start()]
            if not (found.group("generic") and SWIFT_KIND.search(before)):
                yield index, before


def declared(code):
    """このファイルが宣言する View と、拡張する型と、@Observable のクラスの名前を返す。"""
    views = {found.group("name") for line in code if (found := SWIFT_SCREEN.match(line))}
    extended = {found.group("name") for line in code if (found := SWIFT_EXTENSION.match(line))}
    return views, extended, {name for _, _, name, _ in observable_classes(code)}


def read(path):
    try:
        with open(path, encoding="utf-8") as file:
            return file.read()
    except (OSError, UnicodeDecodeError):
        return ""


@functools.cache
def folder_types(folder):
    """フォルダの下の、View の型の名前と、@Observable のクラスの名前を返す。"""
    views, classes = set(), set()
    for text in map(read, sources(folder, ".swift")):
        if EXTENDED_VIEW in text or OBSERVABLE in text:
            found, _, observed = declared(swift_source.mask(text))
            views |= found
            classes |= observed
    return frozenset(views), frozenset(classes)


def screen_types(path):
    """モデルを持たずに View を宣言するモジュールは、@Observable のクラスも画面と見る。モジュールが分からない時は、View だけを見る。"""
    module = swift_module(path)
    views, classes = folder_types(module or os.path.dirname(os.path.realpath(path)))
    if not module or not views or any(module_holds(module, ".swift", part) for part in MODEL_PARTS):
        return views
    return views | classes


def is_screen(path, code):
    views, extended, classes = declared(code)
    return bool(views or EXTENDED_VIEW in extended or (extended | classes) & screen_types(path))


def view_lines(code):
    for index, line in enumerate(code):
        found = SWIFT_SCREEN.match(line)
        if found and found.group("word") != "extension":
            if "{" in line and line.count("{") == line.count("}"):
                yield index
            else:
                yield from range(index, block_end(code, index, found.group(1)))


def kept_tasks(code):
    """View の外で宣言し、cancel で取り消している Task? の保存プロパティの名前を返す。"""
    inside = set(view_lines(code))
    names = {found.group(1) for index, line in enumerate(code) if index not in inside and (found := SWIFT_KEPT.match(line))}
    return {name for name in names if any(re.search(r"(?<![\w.])(?:self\.)?" + name + r"\?\.cancel\(\)", line) for line in code)}


def check_swift_effect(path, code):
    starts = list(task_starts(code))
    if not starts or is_part_library(path) or not is_screen(path, code):
        return
    kept = kept_tasks(code)
    for index, before in starts:
        assigned = SWIFT_ASSIGNED.match(before)
        if not (assigned and assigned.group(1) in kept):
            yield index + 1, SWIFT_EFFECT


def check_kotlin_effect(path, code):
    """スコープを作る行はファイルの全体で、スコープから始める行は最上位の関数の中で見る。@Preview の関数は除く。"""
    if is_part_library(path) or not any(COMPOSABLE.search(line) for line in code):
        return
    for index, line, is_fun, is_preview in top_lines(code):
        found = not is_preview and (KOTLIN_SCOPE.search(line) or (is_fun and KOTLIN_START.search(line)))
        if found:
            yield index + 1, KOTLIN_EFFECT.format(found.group(found.lastindex or 0))
