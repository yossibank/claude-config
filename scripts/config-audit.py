import ast
import fnmatch
import functools
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "lib"))

from hook_io import EDIT_TOOLS  # noqa: E402
from loader import load_hook  # noqa: E402
from md_blocks import fence_marks, front_matter, table_under  # noqa: E402
from md_doc import body_emojis, heading_emojis, read_doc, readme_order, rule_table  # noqa: E402

SKILL_DIR = "${CLAUDE_SKILL_DIR}"
SKILL_PATH = re.compile(r"((?:python3 -I |python3 |bash )?)\$\{CLAUDE_SKILL_DIR\}/((?:\.\./[a-z-]+/)?(?:scripts|templates)/[A-Za-z0-9_.-]+)")
ALIAS = re.compile(r"`(<[A-Z]+>)` は `\$\{CLAUDE_SKILL_DIR\}/([a-z/]+)`")
LINK = re.compile(r"\]\(([^)#\s]+)(?:#[^)]*)?\)")
NG_TO_STDERR = re.compile(r"""(echo|printf)\s+["']?NG\b.*>&2""")
EXIT_FAIL = re.compile(r"\s*exit [1-9]")
RUNTIME_INPUT = re.compile(r"\bsys\.argv\b|\bopen\(|\binput\(|\bsys\.stdin\b|\bsubprocess\.")
HOOK_NAME = re.compile(r"claude-config/hooks/run\.sh\\?\"? ([A-Za-z0-9_-]+)")
REQUIRED_ARG = re.compile(r"\$\{[0-9]:\?")
SKILL_REF = re.compile(r"\$\{CLAUDE_SKILL_DIR\}/([A-Za-z0-9_./-]*)(.?)")
PATH_REF = re.compile(r"(?<![\w./~-])((?:hooks|rules|scripts|lib|skills)/[A-Za-z0-9_./-]*)(.?)")
CONFIG_REF = re.compile(r"(?:claude-config|CLAUDE_CONFIG\)?\}?)/((?:skills/[a-z0-9-]+/scripts|hooks|lib)/[A-Za-z0-9_.-]+)")
WRITE_TOOLS = re.compile(rf"\b(?:{'|'.join(EDIT_TOOLS)})\b")
NAMING = os.path.join(ROOT, "docs", "development.md")
APP_TEMPLATE = os.path.join(ROOT, "skills", "app-init", "templates", "ios-app")
APP_DOCS_TEMPLATE = os.path.join(ROOT, "skills", "app-plan", "templates")
SKILL_SECTIONS = ["起動条件", "入力", "手順", "報告", "制約"]
DESCRIPTION_LIMIT = 120
# 外に出す操作は、走らせるたびに人の許可を求めるよう allowed-tools に入れない
ASK_EVERY_TIME = {"store-release/scripts/archive-app.sh", "store-reply/scripts/send-replies.py"}


@functools.cache
def tracked_files():
    out = subprocess.run(["git", "-C", ROOT, "ls-files", "-z"], capture_output=True, text=True, check=True).stdout
    return tuple(path for path in out.split("\0") if path)


@functools.cache
def tracked(*patterns):
    return tuple(
        os.path.join(ROOT, path)
        for path in tracked_files()
        if any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)
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


def check_skill_sections(skill):
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
        yield from check_skill_sections(skill)


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
            for prefix, reference in SKILL_PATH.findall(line):
                if not os.path.exists(os.path.normpath(os.path.join(base, reference))):
                    continue
                if "scripts/" not in reference:
                    continue
                allowed = covered(prefix, reference, patterns)
                if f"{skill_dir}/{reference}" in ASK_EVERY_TIME:
                    if allowed:
                        yield skill, number, f"外に出す操作が allowed-tools で自動で許可されている: {reference}"
                elif not allowed:
                    yield skill, number, f"allowed-tools で許可していない: {prefix}{reference}"


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
        "hooks": [(path, os.path.basename(path)) for path in tracked("hooks/*.py") if "/lib/" not in path],
        "rules": [(path, os.path.basename(path)) for path in tracked("rules/*.md")],
        "scripts": [(path, os.path.basename(path)) for path in tracked("scripts/*") if "/lib/" not in path],
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
        if len(os.path.relpath(path, ROOT).split(os.sep)) != 4:
            continue
        verb = os.path.basename(path).split(".")[0].split("-")[0]
        if verb not in allowed:
            yield path, 1, f"スキルのスクリプトの頭の動詞が動詞の表に無い: {verb}"


def in_app(path):
    if path.startswith(APP_DOCS_TEMPLATE + os.sep):
        return os.path.join(APP_TEMPLATE, "docs", os.path.relpath(path, APP_DOCS_TEMPLATE))
    return path


def exists_in_app(path):
    docs = os.path.join(APP_TEMPLATE, "docs") + os.sep
    if path.startswith(docs):
        return os.path.exists(os.path.join(APP_DOCS_TEMPLATE, path[len(docs) :]))
    return os.path.exists(path)


def check_links():
    for path in tracked("*.md"):
        template = "/templates/" in path
        place = in_app(path) if template else path
        for number, line in enumerate(read(path).split("\n"), 1):
            for target in LINK.findall(line):
                if re.match(r"[a-z]+:", target) or target.startswith("<"):
                    continue
                if template and ("<" in target or "__" in target):
                    continue
                resolved = os.path.normpath(os.path.join(os.path.dirname(place), target))
                if not (exists_in_app(resolved) if template else os.path.exists(resolved)):
                    yield path, number, f"リンク先が無い: {target}"


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
    files = [path for path in tracked("skills/*/templates/*") if path.endswith((".sh", "/Makefile"))]
    for path in files:
        for number, line in enumerate(read(path).split("\n"), 1):
            for reference in CONFIG_REF.findall(line):
                if not os.path.exists(os.path.join(ROOT, reference)):
                    yield path, number, f"claude-config の参照先が無い: {reference}"


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


def check_shell_scripts():
    shell = load_hook("shell-check")
    for path in tracked("*.sh"):
        for number, message in shell.check(path):
            yield path, number, message
        if os.path.relpath(path, ROOT).startswith("hooks/"):
            continue
        lines = read(path).split("\n")
        for number, line in enumerate(lines, 1):
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
        yield from check_python(path, tree)


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


def check_python(path, tree):
    if "/lib/" not in path and not any(is_main_guard(node) for node in tree.body):
        yield path, 1, 'if __name__ == "__main__": が無い'
    for node in tree.body:
        if runs_on_import(node):
            yield path, node.lineno, "読み込んだだけで処理が走る。main() に入れる"
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
    check_skill_references,
    check_skill_unused,
    check_agents,
    check_claude_templates,
    check_rules,
    check_readme,
    check_readme_flow,
    check_skill_steps,
    check_terms,
    check_prefixes,
    check_script_verbs,
    check_links,
    check_paths,
    check_template_scripts,
    check_settings,
    check_shell_scripts,
    check_python_scripts,
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
