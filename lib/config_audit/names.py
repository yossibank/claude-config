import os
import re

from config_audit.files import NAMING, entry_kinds, entry_targets, naming_table, read, rel, skill_names, tracked
from loader import DOTCLAUDE, ROOT
from md_blocks import table_under


LIB_NAME = re.compile(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*\.(?:jq|py|sh)")
TEST_LIB_NAME = re.compile(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*\.sh")
AGENT_NAME = re.compile(r"[a-z]+er\.md")
HOOK_RUNNER = "run.sh"
LIB_README = os.path.join(ROOT, "lib", "README.md")
DOC_NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\.md")
ENV_NAME = re.compile(r"\bCC_[A-Z][A-Z0-9_]*\b")
COMPONENTS = os.path.join(ROOT, "docs", "config", "components.md")
ENV_HEADING = "## 🔧 環境変数"


def test_targets():
    return {f"tests/{kind}/{name}.sh": path for (kind, name), path in entry_kinds().items()}


def stem_of(path):
    return os.path.splitext(os.path.basename(path))[0]


def check_test_pairs():
    targets = test_targets()
    tests = {rel(path): path for path in tracked("tests/hooks/*.sh", "tests/scripts/*.sh", "tests/skills/*.sh")}
    for name in sorted(targets.keys() - tests.keys()):
        yield targets[name], 1, f"テストが無い: {name}"
    for name in sorted(tests.keys() - targets.keys()):
        yield tests[name], 1, "テストの対象が無い。フォルダに合う hooks/<名前>.py・scripts/<名前>・scripts/ を持つスキルの名前にする"


def prefixes():
    rows = naming_table("### 接頭語の表", "接頭語")
    return {row[0]: {place.strip() for place in row[-1].split("、")} for row in rows}


def check_prefixes():
    table = prefixes()
    if not table:
        yield NAMING, 1, "名前の付け方の接頭語の表が読めない"
        return
    names = {
        "skills": [(os.path.join(DOTCLAUDE, "skills", name, "SKILL.md"), name) for name in skill_names()],
        "hooks": [(path, os.path.basename(path)) for path in tracked("dotclaude/hooks/*.py")],
        "rules": [(path, os.path.basename(path)) for path in tracked("dotclaude/rules/*.md")],
        "scripts": [(path, os.path.basename(path)) for path in tracked("scripts/*")],
    }
    for place, items in names.items():
        for path, name in items:
            prefix = next((p for p in table if name.startswith(p)), None)
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
    for path in tracked("dotclaude/skills/*/scripts/*"):
        verb = os.path.basename(path).split(".")[0].split("-")[0]
        if verb not in allowed:
            yield path, 1, f"スキルのスクリプトの頭の動詞が動詞の表に無い: {verb}"


def check_names():
    listed = read(LIB_README) if os.path.exists(LIB_README) else ""
    for path in tracked("lib/*", "lib/*/*"):
        name = os.path.basename(path)
        if path == LIB_README:
            continue
        if not LIB_NAME.fullmatch(name):
            yield path, 1, "lib の名前は、中身の名詞を snake_case の .jq・.py・.sh にする"
        elif f"]({os.path.relpath(path, os.path.dirname(LIB_README))})" not in listed:
            yield path, 1, "lib/README.md の表に載っていない"
    for path in tracked("tests/support/*"):
        if not TEST_LIB_NAME.fullmatch(os.path.basename(path)):
            yield path, 1, "tests/support の名前は、中身の名詞を snake_case の .sh にする"
    for path in tracked("dotclaude/agents/*"):
        if not AGENT_NAME.fullmatch(os.path.basename(path)):
            yield path, 1, "エージェントの名前は、役割の名詞（-er）の .md にする"
    for path in tracked("dotclaude/hooks/*"):
        name = os.path.basename(path)
        if not name.endswith(".py") and name != HOOK_RUNNER:
            yield path, 1, f"hooks/ に置く .py 以外のファイルは {HOOK_RUNNER} だけにする"
    for path in tracked("docs/*/*.md"):
        if not DOC_NAME.fullmatch(os.path.basename(path)):
            yield path, 1, "docs/ の文書の名前は、名詞の kebab-case の .md にする"


def owners():
    return {name.replace("-", "_") for name in entry_targets()}


def check_lib_owners():
    known = owners()
    folders = {}
    for path in tracked("lib/*/*"):
        folders.setdefault(rel(path).split("/")[1], []).append(path)
    for folder, paths in sorted(folders.items()):
        if folder not in known:
            yield paths[0], 1, f"lib の子フォルダの名前は、持ち主（フック・scripts・スキル）の名前を snake_case にする: {folder}"
    for path in tracked("lib/*"):
        stem = stem_of(path)
        owner = next((name for name in sorted(known) if stem == name or stem.startswith(f"{name}_")), None)
        if owner:
            yield path, 1, f"持ち主が 1 つの中身は、lib の直下に置かない。lib/{owner}/ に置く"


def env_uses():
    uses = {}
    for path in tracked("dotclaude/hooks/*", "scripts/*", "dotclaude/skills/*/scripts/*", "lib/*", "lib/*/*"):
        if path.endswith(".md"):
            continue
        for number, line in enumerate(read(path).split("\n"), 1):
            for name in ENV_NAME.findall(line):
                uses.setdefault(name, (path, number))
    return uses


def check_env_names():
    rows = table_under(read(COMPONENTS).split("\n"), ENV_HEADING, "変数")
    if not rows:
        yield COMPONENTS, 1, "環境変数の表が読めない"
        return
    listed = {name for row in rows for name in ENV_NAME.findall(row[0])}
    uses = env_uses()
    for name in sorted(uses.keys() - listed):
        path, number = uses[name]
        yield path, number, f"環境変数が components.md の環境変数の表に無い: {name}"
    for name in sorted(listed - uses.keys()):
        yield COMPONENTS, 1, f"環境変数の表にあるが、どのフックもスクリプトも読んでいない: {name}"
