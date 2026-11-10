import ast
import os
import re
from concurrent.futures import ThreadPoolExecutor

from config_audit.files import bin_files, is_hook, read, rel, tracked
from loader import load_hook


NG_TO_STDERR = re.compile(r"""(echo|printf)\s+["']?NG\b.*>&2""")
EXIT_FAIL = re.compile(r"\s*exit [1-9]")
RUNTIME_INPUT = re.compile(r"\bsys\.argv\b|\bopen\(|\binput\(|\bsys\.stdin\b|\bsubprocess\.")
REQUIRED_ARG = re.compile(r"\$\{[0-9]:\?")
INLINE_PYTHON = re.compile(r"\bpython3?(?: -I)? -c\b")
TEST_INLINE_PYTHON = re.compile(r"(?:^|[\s$(|;&`])python3?(?: -I)? -c\b")
ENTRY_CALLS = {"hooks": ("run_gate", "run_hook"), "scripts": ("run_main",)}
SCRIPT_HEADER = "set -euo pipefail"
WORKTREES_LITERAL = ".claude/worktrees"


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
        if is_hook(path):
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


def lib_path_line(path):
    here = "os.path.dirname(os.path.realpath(__file__))"
    ups = ", ".join(['".."'] * (len(rel(path).split("/")) - 1))
    folder = here if os.path.dirname(rel(path)) == "lib" else f'os.path.join({here}, {ups}, "lib")'
    return ast.unparse(ast.parse(f"sys.path.insert(0, {folder})"))


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
        if is_path_insert(node) and ast.unparse(node) != lib_path_line(path):
            yield path, node.lineno, f"lib を読む行は、この形にそろえる: {lib_path_line(path)}"
    for node in ast.walk(tree):
        if isinstance(node, ast.Assert):
            yield path, node.lineno, "assert は python -O で消え、トレースバックで落ちる。if で確かめて NG か例外にする"
    if is_hook(path):
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
    for path in tracked("dotclaude/hooks/*.py", "bin/*.py", "dotclaude/skills/*/scripts/*.py", "lib/*.py", "lib/*/*.py"):
        try:
            tree = ast.parse(read(path))
        except SyntaxError:
            continue
        if rel(path).startswith("lib/") and not any(is_main_guard(node) for node in tree.body):
            continue
        top = "hooks" if is_hook(path) else "scripts"
        wanted = ENTRY_CALLS[top]
        if not main_guard_calls(tree) & set(wanted):
            yield path, 1, f"main を {' か '.join(wanted)} で包む。例外で落ちた時に、NG の行か止める文を出すため"


def check_script_entries():
    groups = {}
    for path in bin_files():
        groups.setdefault(os.path.splitext(os.path.basename(path))[0], []).append(path)
    for stem, paths in sorted(groups.items()):
        entries = [path for path in paths if path.endswith(".sh")] or sorted(paths)[:1]
        for path in sorted(set(paths) - set(entries[:1])):
            yield path, 1, f"bin/ には入口だけを置く。同じ名前の中身は lib/ に移す: {stem}"


def check_test_inline_python():
    for path in tracked("tests/*/*.sh"):
        for number, line in enumerate(read(path).split("\n"), 1):
            if TEST_INLINE_PYTHON.search(line):
                yield path, number, "テストの中に python3 -c を書かない。jq・bash で書くか、.py に分ける"
