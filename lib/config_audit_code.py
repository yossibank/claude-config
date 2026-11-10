import ast
import json
import os
import re
from concurrent.futures import ThreadPoolExecutor

from config_audit_files import read, tracked
from hook_io import FILE_EDIT_TOOLS
from loader import DOTCLAUDE, ROOT, load_hook


NG_TO_STDERR = re.compile(r"""(echo|printf)\s+["']?NG\b.*>&2""")
EXIT_FAIL = re.compile(r"\s*exit [1-9]")
RUNTIME_INPUT = re.compile(r"\bsys\.argv\b|\bopen\(|\binput\(|\bsys\.stdin\b|\bsubprocess\.")
HOOK_NAME = re.compile(r"\.claude/hooks/run\.sh\\?\"? ([A-Za-z0-9_-]+)")
REQUIRED_ARG = re.compile(r"\$\{[0-9]:\?")
INLINE_PYTHON = re.compile(r"\bpython3?(?: -I)? -c\b")
TEST_INLINE_PYTHON = re.compile(r"(?:^|[\s$(|;&`])python3?(?: -I)? -c\b")
ENTRY_CALLS = {"hooks": ("run_gate", "run_hook"), "scripts": ("run_main",)}
SCRIPT_HEADER = "set -euo pipefail"
WORKTREES_LITERAL = ".claude/worktrees"
CONFIG_REF = re.compile(r"(?:claude-config|CLAUDE_CONFIG\)?\}?)/((?:(?:dotclaude/)?(?:skills/[a-z0-9-]+/scripts|hooks)|lib)/[A-Za-z0-9_.-]+)")
TEMPLATE_TOKEN = re.compile(r"__[A-Za-z]+__")
REPLACER = os.path.join(DOTCLAUDE, "skills", "app-init", "scripts", "replace-placeholders.py")


def check_template_scripts():
    files = [path for path in tracked("dotclaude/skills/*/templates/**") if path.endswith((".sh", "/Makefile"))]
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
    for path in tracked("dotclaude/skills/app-init/templates/**"):
        for number, line in template_tokens(path):
            for token in sorted(set(TEMPLATE_TOKEN.findall(line)) - tokens):
                yield path, number, f"replace-placeholders.py の tokens に無い印: {token}"


def check_settings():
    path = os.path.join(DOTCLAUDE, "settings.json")
    for group in json.loads(read(path)).get("hooks", {}).values():
        for entry in group:
            for hook in entry.get("hooks", []):
                command = hook.get("command", "")
                names = HOOK_NAME.findall(command)
                if not names:
                    yield path, 1, f"フックを hooks/run.sh で呼んでいない: {command[:60]}"
                for name in names:
                    if not os.path.isfile(os.path.join(DOTCLAUDE, "hooks", f"{name}.py")):
                        yield path, 1, f"フックのファイルが無い: hooks/{name}.py"
            tools = set((entry.get("matcher") or "").split("|"))
            if tools & set(FILE_EDIT_TOOLS) and tools != set(FILE_EDIT_TOOLS):
                yield path, 1, f"編集の matcher は hook_io の FILE_EDIT_TOOLS と同じ {'|'.join(FILE_EDIT_TOOLS)} にする: {entry.get('matcher')}"


def check_worktree_literals():
    for path in tracked("dotclaude/hooks/*", "scripts/*", "dotclaude/skills/*/scripts/*"):
        if path == os.path.abspath(__file__):
            continue
        for number, line in enumerate(read(path).split("\n"), 1):
            if WORKTREES_LITERAL in line:
                yield path, number, "ワークツリーの置き場所は lib の worktree_root・WORKTREES を使う"


def check_shell_scripts():
    shell = load_hook("shell-check")
    strict = set(tracked("dotclaude/skills/*/scripts/*.sh", "scripts/*.sh"))
    paths = tracked("*.sh")
    with ThreadPoolExecutor() as pool:
        found = list(pool.map(shell.check, paths))
    for path, problems in zip(paths, found):
        for number, message in problems:
            yield path, number, message
        if os.path.relpath(path, ROOT).startswith("dotclaude/hooks/"):
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
    if os.path.relpath(path, ROOT).startswith("dotclaude/hooks/"):
        return
    for node in ast.walk(tree):
        if is_exit_with_text(node):
            yield path, node.lineno, "sys.exit に文を渡すと stderr に出る。stdout に NG を出して sys.exit(1) にする"


def main_guard_calls(tree):
    for node in tree.body:
        if is_main_guard(node):
            return {ast.unparse(call.func) for call in ast.walk(node) if isinstance(call, ast.Call)}
    return set()


def check_entry_wrappers():
    for path in tracked("dotclaude/hooks/*.py", "scripts/*.py", "dotclaude/skills/*/scripts/*.py"):
        try:
            tree = ast.parse(read(path))
        except SyntaxError:
            continue
        top = "hooks" if os.path.relpath(path, ROOT).startswith("dotclaude/hooks/") else "scripts"
        wanted = ENTRY_CALLS[top]
        if not main_guard_calls(tree) & set(wanted):
            yield path, 1, f"main を {' か '.join(wanted)} で包む。例外で落ちた時に、NG の行か止める文を出すため"


def check_script_entries():
    groups = {}
    for path in tracked("scripts/*"):
        groups.setdefault(os.path.splitext(os.path.basename(path))[0], []).append(path)
    for stem, paths in sorted(groups.items()):
        for path in sorted(paths)[1:]:
            yield path, 1, f"scripts/ には入口だけを置く。同じ名前の中身は lib/ に移す: {stem}"


def check_test_inline_python():
    for path in tracked("tests/*.sh", "tests/support/*.sh"):
        for number, line in enumerate(read(path).split("\n"), 1):
            if TEST_INLINE_PYTHON.search(line):
                yield path, number, "テストの中に python3 -c を書かない。jq・bash で書くか、.py に分ける"
