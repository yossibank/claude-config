import ast
import fnmatch
import functools
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import EDIT_TOOLS, FILE_EDIT_TOOLS  # noqa: E402
from loader import ROOT, load_hook  # noqa: E402
from md_blocks import fence_marks, front_matter, table_under  # noqa: E402
from md_doc import body_emojis, heading_emojis, read_doc, readme_order, rule_table  # noqa: E402
from script_io import fail  # noqa: E402

SKILL_DIR = "${CLAUDE_SKILL_DIR}"
SKILL_PATH = re.compile(r"((?:python3 -I |python3 |bash )?)\$\{CLAUDE_SKILL_DIR\}/((?:\.\./[a-z-]+/)?(?:scripts|templates)/[A-Za-z0-9_.-]+)")
ALIAS = re.compile(r"`(<[A-Z]+>)` は `\$\{CLAUDE_SKILL_DIR\}/([a-z/]+)`")
LINK = re.compile(r"\]\(([^)#\s]+)(?:#[^)]*)?\)")
ANCHOR_LINK = re.compile(r"\]\(([^)#\s]*)#([^)\s]+)\)")
INLINE_CODE = re.compile(r"`[^`]*`")
NG_TO_STDERR = re.compile(r"""(echo|printf)\s+["']?NG\b.*>&2""")
EXIT_FAIL = re.compile(r"\s*exit [1-9]")
RUNTIME_INPUT = re.compile(r"\bsys\.argv\b|\bopen\(|\binput\(|\bsys\.stdin\b|\bsubprocess\.")
HOOK_NAME = re.compile(r"claude-config/hooks/run\.sh\\?\"? ([A-Za-z0-9_-]+)")
REQUIRED_ARG = re.compile(r"\$\{[0-9]:\?")
INLINE_PYTHON = re.compile(r"\bpython3?(?: -I)? -c\b")
SCRIPT_HEADER = "set -euo pipefail"
WORKTREES_LITERAL = ".claude/worktrees"
SKILL_REF = re.compile(r"\$\{CLAUDE_SKILL_DIR\}/([A-Za-z0-9_./-]*)(.?)")
PATH_REF = re.compile(r"(?<![\w./~-])((?:hooks|rules|scripts|lib|skills)/[A-Za-z0-9_./-]*)(.?)")
CONFIG_REF = re.compile(r"(?:claude-config|CLAUDE_CONFIG\)?\}?)/((?:skills/[a-z0-9-]+/scripts|hooks|lib)/[A-Za-z0-9_.-]+)")
TEMPLATE_TOKEN = re.compile(r"__[A-Za-z]+__")
LIB_NAME = re.compile(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*\.(?:py|sh)")
TEST_LIB_NAME = re.compile(r"[a-z][a-z0-9]*(?:_[a-z0-9]+)*\.sh")
AGENT_NAME = re.compile(r"[a-z]+er\.md")
HOOK_RUNNER = "run.sh"
WRITE_TOOLS = re.compile(rf"\b(?:{'|'.join(EDIT_TOOLS)})\b")
NAMING = os.path.join(ROOT, "docs", "development.md")
APP_TEMPLATE = os.path.join(ROOT, "skills", "app-init", "templates", "ios-app")
REPLACER = os.path.join(ROOT, "skills", "app-init", "scripts", "replace-placeholders.py")
SKILL_SECTIONS = ["起動条件", "入力", "手順", "報告", "制約"]
DESCRIPTION_LIMIT = 120
# 外に出す操作は、走らせるたびに人の許可を求めるよう allowed-tools に入れない
ASK_EVERY_TIME = {"store-release/scripts/archive-app.sh", "store-reply/scripts/send-replies.py"}


@functools.cache
def tracked_files():
    try:
        out = subprocess.run(["git", "-C", ROOT, "ls-files", "-z"], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        fail(f"git ls-files が通らない。{ROOT} が Git のリポジトリかを確かめる")
    return tuple(path for path in out.split("\0") if path)


def path_matches(path, pattern):
    if "/" not in pattern:
        return fnmatch.fnmatchcase(os.path.basename(path), pattern)
    parts, wants = path.split("/"), pattern.split("/")
    if wants[-1] == "**":
        wants = wants[:-1]
        parts = parts[: len(wants)] if len(parts) > len(wants) else []
    return len(parts) == len(wants) and all(fnmatch.fnmatchcase(part, want) for part, want in zip(parts, wants))


@functools.cache
def tracked(*patterns):
    return tuple(
        os.path.join(ROOT, path)
        for path in tracked_files()
        if any(path_matches(path, pattern) for pattern in patterns)
    )


@functools.cache
def read(path):
    return Path(path).read_text(encoding="utf-8")


def fields_of(path):
    return front_matter(read(path).split("\n")) or {}


def outside_code(path):
    lines = read(path).split("\n")
    return [(number, line) for number, (line, (mark, _)) in enumerate(zip(lines, fence_marks(lines)), 1) if mark is None]


def headings(path):
    return [(number, line[3:].strip()) for number, line in outside_code(path) if line.startswith("## ")]


def skill_section_problems(skill):
    found = headings(skill)
    names = [name for _, name in found]
    for need in ("手順", "報告"):
        if need not in names:
            yield skill, 1, f"## {need} が無い"
    fixed = [(number, name) for number, name in found if name in SKILL_SECTIONS]
    for (_, before), (number, after) in zip(fixed, fixed[1:]):
        if SKILL_SECTIONS.index(before) >= SKILL_SECTIONS.index(after):
            yield skill, number, f"## {after} は {'・'.join(SKILL_SECTIONS)} の順に置く"
    if "手順" in names and "報告" in names:
        start, end = names.index("手順"), names.index("報告")
        for index, (number, name) in enumerate(found):
            if name not in SKILL_SECTIONS and not start < index < end:
                yield skill, number, f"## {name} は、## 手順 と ## 報告 の間に置く"


def allowed_patterns(fields):
    return re.findall(r"Bash\(([^)]*)\)", fields.get("allowed-tools", ""))


def expand_aliases(text):
    for alias, target in ALIAS.findall(text):
        text = text.replace(f"{alias}/", f"{SKILL_DIR}/{target}/")
    return text


def covered(prefix, reference, patterns):
    command = f"{prefix}{SKILL_DIR}/{reference} x"
    return any(fnmatch.fnmatchcase(command, pattern) for pattern in patterns)


def skill_names():
    return sorted(os.path.basename(os.path.dirname(path)) for path in tracked("skills/*/SKILL.md"))


@functools.cache
def expanded_skills():
    return tuple(expand_aliases(read(path)) for path in tracked("skills/*/SKILL.md"))


def check_skill_fields():
    for skill_dir in skill_names():
        skill = os.path.join(ROOT, "skills", skill_dir, "SKILL.md")
        fields = fields_of(skill)
        if fields.get("name") != skill_dir:
            yield skill, 2, f"name がフォルダ名 {skill_dir} と違う: {fields.get('name')}"
        if not fields.get("description", "").endswith("。"):
            yield skill, 3, "description を「。」で終える"
        if len(fields.get("description", "")) > DESCRIPTION_LIMIT:
            yield skill, 3, f"description が {DESCRIPTION_LIMIT} 字を超えている。毎回読み込まれるので短くする"
        yield from skill_section_problems(skill)


def script_permission_problems(skill_dir, line, patterns):
    base = os.path.join(ROOT, "skills", skill_dir)
    for prefix, reference in SKILL_PATH.findall(line):
        if "scripts/" not in reference or not os.path.exists(os.path.normpath(os.path.join(base, reference))):
            continue
        allowed = covered(prefix, reference, patterns)
        if f"{skill_dir}/{reference}" in ASK_EVERY_TIME:
            if allowed:
                yield f"外に出す操作が allowed-tools で自動で許可されている: {reference}"
        elif not allowed:
            yield f"allowed-tools で許可していない: {prefix}{reference}"


def check_skill_references():
    for skill_dir in skill_names():
        base = os.path.join(ROOT, "skills", skill_dir)
        skill = os.path.join(base, "SKILL.md")
        patterns = allowed_patterns(fields_of(skill))
        for number, line in enumerate(expand_aliases(read(skill)).split("\n"), 1):
            if line.startswith("allowed-tools:"):
                continue
            for reference, after in SKILL_REF.findall(line):
                reference = reference.rstrip("./")
                if reference and after not in ("<", "*") and not os.path.exists(os.path.join(base, reference)):
                    yield skill, number, f"参照先が無い: {reference}"
            for message in script_permission_problems(skill_dir, line, patterns):
                yield skill, number, message


def check_skill_unused():
    for skill_dir in skill_names():
        yield from unused_scripts(skill_dir)


def unused_scripts(skill_dir):
    scripts = tracked(f"skills/{skill_dir}/scripts/*")
    own_skill = expand_aliases(read(os.path.join(ROOT, "skills", skill_dir, "SKILL.md")))
    for path in scripts:
        name = os.path.basename(path)
        in_own_skill = f"{SKILL_DIR}/scripts/{name}" in own_skill
        in_other_skill = any(f"{SKILL_DIR}/../{skill_dir}/scripts/{name}" in text for text in expanded_skills())
        in_sibling = any(
            re.search(rf"[/\"'\s]{re.escape(name)}\b", read(sibling)) for sibling in scripts if sibling != path
        )
        if not (in_own_skill or in_other_skill or in_sibling):
            yield path, 1, "どこからも使われていない"


def check_agents():
    for path in tracked("agents/*.md"):
        fields = fields_of(path)
        name = os.path.splitext(os.path.basename(path))[0]
        if fields.get("name") != name:
            yield path, 2, f"name がファイル名 {name} と違う: {fields.get('name')}"
        if not fields.get("model"):
            yield path, 1, "model が無い"
        found = headings(path)
        if not found or found[-1][1] != "返す形":
            yield path, found[-1][0] if found else 1, "agents の最後の ## は「返す形」にする"
        body = read(path).split("\n---\n", 1)[-1]
        tools = fields.get("tools")
        if "書き換えない" in body and (tools is None or WRITE_TOOLS.search(tools)):
            yield path, 1, f"書き換えないエージェントは tools を書き、{'・'.join(EDIT_TOOLS)} を入れない"


def check_claude_templates():
    order = [row[1] for row in rule_table("## CLAUDE.md の形", "順")][1:-1]
    if not order:
        yield os.path.join(ROOT, "rules", "docs-claude.md"), 1, "CLAUDE.md の形の表が読めない"
        return
    for path in tracked("skills/*/templates/*/CLAUDE.md"):
        top = 0
        for number, name in headings(path):
            rank = order.index(name) if name in order else len(order)
            if rank < top:
                yield path, number, f"CLAUDE.md の ## は {'・'.join(order)}・ほかの節の順に並べる"
            top = max(top, rank)


def check_rules():
    for path in tracked("rules/*.md"):
        if "paths" not in fields_of(path):
            yield path, 1, "frontmatter に paths が無い"


def check_readme():
    readme = os.path.join(ROOT, "README.md")
    links = {target.rstrip("/") for target in LINK.findall(read(readme))}
    entries = [f"skills/{name}/SKILL.md" for name in skill_names()]
    entries += [os.path.relpath(path, ROOT) for path in tracked("agents/*.md", "output-styles/*.md", "rules/*.md", "hooks/*.py", "hooks/*.sh", "scripts/*")]
    for entry in entries:
        if entry not in links:
            yield readme, 1, f"README の表に載っていない: {entry}"


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


def check_readme_flow():
    readme = os.path.join(ROOT, "README.md")
    section = re.search(r"^## 🧰 .*?(?=^## |\Z)", read(readme), re.M | re.S)
    flow = "".join(re.findall(r"```mermaid\n(.*?)```", section.group(0), re.S)) if section else ""
    if not flow:
        yield readme, 1, "## 🧰 スキルの節に、スキルを使う順の Mermaid の図が無い"
        return
    for name in skill_names():
        if not re.search(rf"(?<![A-Za-z0-9_-]){re.escape(name)}(?![A-Za-z0-9_-])", flow):
            yield readme, 1, f"スキルを使う順の図に載っていない: {name}"


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


def check_skill_steps():
    for name in skill_names():
        skill = os.path.join(ROOT, "skills", name, "SKILL.md")
        steps = re.search(r"^## 手順\n(.*?)(?=^## |\Z)", read(skill), re.M | re.S)
        if steps and not re.search(r"^1\. ", steps.group(1), re.M):
            yield skill, 1, "「手順」は番号付きの箇条書きで書く"


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
        "rules": [(path, os.path.basename(path)) for path in tracked("rules/*.md")],
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


def check_links():
    for path in tracked("*.md"):
        template = "/templates/" in path
        for number, line in enumerate(read(path).split("\n"), 1):
            for target in LINK.findall(line):
                if re.match(r"[a-z]+:", target) or target.startswith("<"):
                    continue
                if template and ("<" in target or "__" in target):
                    continue
                resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
                if not os.path.exists(resolved):
                    yield path, number, f"リンク先が無い: {target}"


def slug(title):
    text = re.sub(r"[^\w\- ]", "", title.replace("`", "").strip().lower())
    return text.replace(" ", "-")


@functools.cache
def anchors_of(path):
    anchors = set()
    for _, line in outside_code(path):
        if re.match(r"#{1,6} ", line):
            base = slug(line.lstrip("#"))
            anchor, count = base, 0
            while anchor in anchors:
                count += 1
                anchor = f"{base}-{count}"
            anchors.add(anchor)
    return anchors


def check_anchors():
    for path in tracked("*.md"):
        for number, line in outside_code(path):
            for target, anchor in ANCHOR_LINK.findall(INLINE_CODE.sub("", line)):
                if re.match(r"[a-z]+:", target):
                    continue
                resolved = os.path.normpath(os.path.join(os.path.dirname(path), target)) if target else path
                if resolved.endswith(".md") and os.path.isfile(resolved) and anchor not in anchors_of(resolved):
                    yield path, number, f"リンク先の見出しが無い: {target}#{anchor}"


def path_bases(path):
    bases = [ROOT, os.path.dirname(path), APP_TEMPLATE]
    parts = os.path.relpath(path, ROOT).split(os.sep)
    if parts[0] == "skills" and len(parts) > 2:
        bases.append(os.path.join(ROOT, "skills", parts[1]))
    return bases


def check_paths():
    for path in tracked("*.md"):
        for number, line in outside_code(path):
            for reference, after in PATH_REF.findall(line):
                reference = reference.rstrip(".")
                if after in ("<", "*") or any(os.path.exists(os.path.join(base, reference)) for base in path_bases(path)):
                    continue
                yield path, number, f"参照先が無い: {reference}"


def check_template_scripts():
    files = [path for path in tracked("skills/*/templates/**") if path.endswith((".sh", "/Makefile"))]
    for path in files:
        for number, line in enumerate(read(path).split("\n"), 1):
            for reference in CONFIG_REF.findall(line):
                if not os.path.exists(os.path.join(ROOT, reference)):
                    yield path, number, f"claude-config の参照先が無い: {reference}"


def replacer_tokens(tree):
    for node in ast.walk(tree):
        if not isinstance(node, ast.List):
            continue
        for item in node.elts:
            if isinstance(item, ast.Tuple) and len(item.elts) == 2 and isinstance(item.elts[0], ast.Constant):
                yield item.lineno, item.elts[0].value


def literal_replaces(tree):
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "replace":
            if node.args and isinstance(node.args[0], ast.Constant):
                yield node.lineno, node.args[0].value


def template_tokens(path):
    yield 1, os.path.relpath(path, ROOT)
    try:
        yield from enumerate(read(path).split("\n"), 1)
    except UnicodeDecodeError:
        return


def check_template_tokens():
    tree = ast.parse(read(REPLACER))
    tokens = set()
    for number, token in replacer_tokens(tree):
        if isinstance(token, str) and TEMPLATE_TOKEN.fullmatch(token):
            tokens.add(token)
        else:
            yield REPLACER, number, f"tokens に __<名前>__ でない文字列がある: {token}"
    for number, text in literal_replaces(tree):
        yield REPLACER, number, f"tokens を通さずに文字列を置き換えている: {text}"
    for path in tracked("skills/app-init/templates/**"):
        for number, line in template_tokens(path):
            for token in sorted(set(TEMPLATE_TOKEN.findall(line)) - tokens):
                yield path, number, f"replace-placeholders.py の tokens に無い印: {token}"


def check_settings():
    path = os.path.join(ROOT, "settings", "settings.json")
    for group in json.loads(read(path)).get("hooks", {}).values():
        for entry in group:
            for hook in entry.get("hooks", []):
                command = hook.get("command", "")
                names = HOOK_NAME.findall(command)
                if not names:
                    yield path, 1, f"フックを hooks/run.sh で呼んでいない: {command[:60]}"
                for name in names:
                    if not os.path.isfile(os.path.join(ROOT, "hooks", f"{name}.py")):
                        yield path, 1, f"フックのファイルが無い: hooks/{name}.py"
            tools = set((entry.get("matcher") or "").split("|"))
            if tools & set(FILE_EDIT_TOOLS) and tools != set(FILE_EDIT_TOOLS):
                yield path, 1, f"編集の matcher は hook_io の FILE_EDIT_TOOLS と同じ {'|'.join(FILE_EDIT_TOOLS)} にする: {entry.get('matcher')}"


def check_worktree_literals():
    for path in tracked("hooks/*", "scripts/*", "skills/*/scripts/*"):
        if path == os.path.abspath(__file__):
            continue
        for number, line in enumerate(read(path).split("\n"), 1):
            if WORKTREES_LITERAL in line:
                yield path, number, "ワークツリーの置き場所は lib の worktree_root・WORKTREES を使う"


def check_shell_scripts():
    shell = load_hook("shell-check")
    strict = set(tracked("skills/*/scripts/*.sh", "scripts/*.sh"))
    for path in tracked("*.sh"):
        for number, message in shell.check(path):
            yield path, number, message
        if os.path.relpath(path, ROOT).startswith("hooks/"):
            continue
        lines = read(path).split("\n")
        if path in strict and lines[1:2] != [SCRIPT_HEADER]:
            yield path, 2, f"2 行目を {SCRIPT_HEADER} にする"
        for number, line in enumerate(lines, 1):
            if path in strict and INLINE_PYTHON.search(line):
                yield path, number, "bash の中に Python を書かない。.py に分けるか、jq と bash で書く"
            failing = number < len(lines) and EXIT_FAIL.match(lines[number])
            if NG_TO_STDERR.search(line) or (">&2" in line and failing) or ("NG" in line and "/dev/stderr" in line):
                yield path, number, "失敗を stderr に出している。stdout に NG で始めて出す"
            if REQUIRED_ARG.search(line):
                yield path, number, "${N:?} は stderr に出て止まる。[[ $# -ge N ]] で確かめ、stdout に NG を出す"


def check_python_scripts():
    for path in tracked("*.py"):
        try:
            tree = ast.parse(read(path))
        except SyntaxError as error:
            yield path, error.lineno or 1, f"Python の構文が通らない: {error.msg}"
            continue
        yield from python_problems(path, tree)


def is_main_guard(node):
    return isinstance(node, ast.If) and "__name__" in ast.unparse(node.test)


def is_exit_code(node):
    if isinstance(node, ast.IfExp):
        return is_exit_code(node.body) and is_exit_code(node.orelse)
    return isinstance(node, ast.Constant) and isinstance(node.value, int)


def is_exit_with_text(node):
    return (
        isinstance(node, ast.Call)
        and ast.unparse(node.func) in ("sys.exit", "exit", "SystemExit")
        and bool(node.args)
        and not is_exit_code(node.args[0])
    )


def is_path_insert(node):
    return isinstance(node, ast.Expr) and ast.unparse(node.value).startswith("sys.path.insert(")


def runs_on_import(node):
    if isinstance(node, (ast.Import, ast.ImportFrom, ast.FunctionDef, ast.ClassDef)) or is_main_guard(node):
        return False
    if is_path_insert(node):
        return False
    if isinstance(node, ast.Expr):
        return not isinstance(node.value, ast.Constant)
    if isinstance(node, (ast.Assign, ast.AnnAssign)):
        return bool(RUNTIME_INPUT.search(ast.unparse(node)))
    return True


def python_problems(path, tree):
    if "/lib/" not in path and not any(is_main_guard(node) for node in tree.body):
        yield path, 1, 'if __name__ == "__main__": が無い'
    for node in tree.body:
        if runs_on_import(node):
            yield path, node.lineno, "読み込んだだけで処理が走る。main() に入れる"
    for node in ast.walk(tree):
        if isinstance(node, ast.Assert):
            yield path, node.lineno, "assert は python -O で消え、トレースバックで落ちる。if で確かめて NG か例外にする"
    if os.path.relpath(path, ROOT).startswith("hooks/"):
        return
    for node in ast.walk(tree):
        if is_exit_with_text(node):
            yield path, node.lineno, "sys.exit に文を渡すと stderr に出る。stdout に NG を出して sys.exit(1) にする"


def check_docs():
    docs = load_hook("docs-check")
    if not heading_emojis() or not body_emojis() or not readme_order():
        yield os.path.join(ROOT, "rules", "docs-human.md"), 1, "見出しの絵文字・本文の絵文字・README の形のどれかの表が読めない"
    for path in tracked("*.md"):
        for number, message in docs.check(path):
            yield path, number, message


CHECKS = [
    check_skill_fields,
    check_skill_steps,
    check_skill_references,
    check_skill_unused,
    check_claude_templates,
    check_template_scripts,
    check_template_tokens,
    check_agents,
    check_rules,
    check_settings,
    check_prefixes,
    check_script_verbs,
    check_names,
    check_test_pairs,
    check_shell_scripts,
    check_python_scripts,
    check_worktree_literals,
    check_readme,
    check_readme_flow,
    check_terms,
    check_links,
    check_anchors,
    check_paths,
    check_docs,
]


def main():
    problems = [f"NG {os.path.relpath(path, ROOT)}:{line} {message}" for check in CHECKS for path, line, message in check()]
    if problems:
        print("\n".join(problems))
        print(f"NG config-audit: {len(problems)} 件")
        sys.exit(1)
    print("OK config-audit")


if __name__ == "__main__":
    main()
