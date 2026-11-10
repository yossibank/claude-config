import os
import re

from audit_files import read, tracked
from audit_skills import skill_names
from loader import ROOT
from md_blocks import table_under
from md_doc import read_doc


LIB_NAME = re.compile(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*\.(?:py|sh)")
TEST_LIB_NAME = re.compile(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*\.sh")
AGENT_NAME = re.compile(r"[a-z]+er\.md")
HOOK_RUNNER = "run.sh"
NAMING = os.path.join(ROOT, "docs", "config-development.md")


def test_targets():
    targets = {}
    for path in tracked("hooks/*.py", "scripts/*"):
        targets.setdefault(os.path.splitext(os.path.basename(path))[0], path)
    for path in tracked("skills/*/scripts/*"):
        skill = os.path.relpath(path, ROOT).split(os.sep)[1]
        targets.setdefault(skill, os.path.join(ROOT, "skills", skill, "SKILL.md"))
    return targets


def check_test_pairs():
    targets = test_targets()
    tests = {os.path.splitext(os.path.basename(path))[0]: path for path in tracked("tests/*.sh")}
    for name in sorted(targets.keys() - tests.keys()):
        yield targets[name], 1, f"テストが無い: tests/{name}.sh"
    for name in sorted(tests.keys() - targets.keys()):
        yield tests[name], 1, "テストの対象が無い。hooks/<名前>.py・scripts/<名前>・scripts/ を持つスキルの名前にする"


def naming_table(heading, first_column):
    return table_under(read(NAMING).split("\n"), heading, first_column)


def term_pattern(word):
    edge = r"[A-Za-z0-9_./-]"
    return re.compile(rf"(?<!{edge}){re.escape(word)}(?!{edge})" if word.isascii() else re.escape(word))


def check_terms():
    table = naming_table("### そろえる語", "使う語")
    if not table:
        yield NAMING, 1, "名前の付け方のそろえる語の表が読めない"
        return
    patterns = [(use, avoid, term_pattern(avoid)) for use, avoid in table]
    for path in tracked("*.md"):
        for row in read_doc(path).rows:
            for use, avoid, pattern in patterns:
                if path == NAMING and row.text.strip().startswith(f"| {use} |"):
                    continue
                if pattern.search(row.text):
                    yield path, row.number, f"「{avoid}」ではなく「{use}」と書く（そろえる語の表）"


def prefixes():
    rows = naming_table("### 接頭語の表", "接頭語")
    return {row[0]: {place.strip() for place in row[-1].split("、")} for row in rows}


def check_prefixes():
    table = prefixes()
    if not table:
        yield NAMING, 1, "名前の付け方の接頭語の表が読めない"
        return
    names = {
        "skills": [(os.path.join(ROOT, "skills", name, "SKILL.md"), name) for name in skill_names()],
        "hooks": [(path, os.path.basename(path)) for path in tracked("hooks/*.py")],
        "docs": [(path, os.path.basename(path)) for path in tracked("docs/*.md")],
        "rules": [(path, os.path.basename(path)) for path in tracked("rules/*.md")],
        "scripts": [(path, os.path.basename(path)) for path in tracked("scripts/*")],
        "lib": [(path, os.path.basename(path)) for path in tracked("lib/*_*")],
    }
    for place, items in names.items():
        for path, name in items:
            key = name.replace("_", "-") if place == "lib" else name
            prefix = next((p for p in table if key.startswith(p)), None)
            if prefix is None:
                yield path, 1, f"名前の接頭語が接頭語の表に無い: {name}"
            elif place not in table[prefix]:
                yield path, 1, f"接頭語 {prefix} は {place} に使わない（接頭語の表の使う所）"


def verbs():
    return {verb.strip("`") for row in naming_table("### 動詞の表", "動詞") for verb in row[0].split("・")}


def check_script_verbs():
    allowed = verbs()
    if not allowed:
        yield NAMING, 1, "名前の付け方の動詞の表が読めない"
        return
    for path in tracked("skills/*/scripts/*"):
        verb = os.path.basename(path).split(".")[0].split("-")[0]
        if verb not in allowed:
            yield path, 1, f"スキルのスクリプトの頭の動詞が動詞の表に無い: {verb}"


def check_names():
    for path in tracked("lib/*"):
        if not LIB_NAME.fullmatch(os.path.basename(path)):
            yield path, 1, "lib の名前は、中身の名詞を snake_case の .py か .sh にする"
    for path in tracked("tests/lib/*"):
        if not TEST_LIB_NAME.fullmatch(os.path.basename(path)):
            yield path, 1, "tests/lib の名前は、中身の名詞を snake_case の .sh にする"
    for path in tracked("agents/*"):
        if not AGENT_NAME.fullmatch(os.path.basename(path)):
            yield path, 1, "エージェントの名前は、役割の名詞（-er）の .md にする"
    for path in tracked("hooks/*"):
        name = os.path.basename(path)
        if not name.endswith(".py") and name != HOOK_RUNNER:
            yield path, 1, f"hooks/ に置く .py 以外のファイルは {HOOK_RUNNER} だけにする"
