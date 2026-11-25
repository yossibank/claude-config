import functools
import os
import re

import swift_source
from hooks.code_design_check.files import is_test
from hooks.code_design_check.state import SWIFT_ACCESS, observable_classes

SWIFT_ROOT = "Sources"
GRADLE = ("build.gradle.kts", "build.gradle")
BUILT = {"build", ".build", ".gradle"}
KOTLIN_HOLDER = re.compile(r"^    (?:(?:public|internal|private)\s+)?va[lr]\s+input\s*(?::[^=\n]+)?=\s*Input\(", re.MULTILINE)
OBSERVABLE = "@Observable"


def has_gradle(folder):
    return any(os.path.isfile(os.path.join(folder, name)) for name in GRADLE)


def swift_module(path):
    folders = os.path.realpath(path).split(os.sep)[:-1]
    roots = [index for index, folder in enumerate(folders[:-1]) if folder == SWIFT_ROOT]
    return os.sep.join(folders[: roots[-1] + 2]) if roots else ""


def kotlin_module(path):
    folder = os.path.dirname(os.path.realpath(path))
    while folder != os.path.dirname(folder):
        if has_gradle(folder):
            return folder
        folder = os.path.dirname(folder)
    return ""


def module_of(path):
    return swift_module(path) if path.endswith(".swift") else kotlin_module(path)


@functools.cache
def sources(module, suffix):
    found = []
    for folder, names, files in os.walk(module):
        names[:] = [name for name in names if name not in BUILT and not has_gradle(os.path.join(folder, name))]
        found += [os.path.join(folder, name) for name in files if name.endswith(suffix)]
    return tuple(path for path in found if not is_test(path))


def swift_holds(text, part):
    if OBSERVABLE not in text or part not in text:
        return False
    code = swift_source.mask(text)
    for start, end, _, indent in observable_classes(code):
        member = re.compile("^" + indent + "    " + SWIFT_ACCESS + r"(?:let|var)\s+" + part + r"\s*[:=]")
        if any(member.match(code[index]) for index in range(start + 1, end)):
            return True
    return False


def holds(path, part):
    try:
        with open(path, encoding="utf-8") as file:
            text = file.read()
    except (OSError, UnicodeDecodeError):
        return False
    return swift_holds(text, part) if path.endswith(".swift") else bool(KOTLIN_HOLDER.search(text))


@functools.cache
def module_holds(module, suffix, part):
    return any(holds(path, part) for path in sources(module, suffix))


def is_open_to(path, part):
    """このファイルから、モデルの part に型の守り無しで届くか。モジュールが分からない時は、届くと見る。"""
    module = module_of(path)
    return not module or module_holds(module, os.path.splitext(path)[1], part)
