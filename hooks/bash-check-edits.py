import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile

HOOKS = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.join(tempfile.gettempdir(), "claude-bash-edits")
CHECKED = (".md", ".swift", ".sh", ".py", ".kt", ".kts", ".yml", ".yaml", ".json")
TOOLS = re.compile(r"^\s*(git|make|mint|swiftformat|pre-commit|gh|brew|xcodebuild|swift)\b")


def changed_files(cwd):
    result = subprocess.run(
        ["git", "-C", cwd, "status", "--porcelain", "--untracked-files=all"],
        capture_output=True,
        text=True,
    )
    if result.returncode:
        return None, {}
    root = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    files = {}
    for line in result.stdout.splitlines():
        path = os.path.join(root, line[3:].split(" -> ")[-1].strip('"'))
        if os.path.isfile(path):
            files[path] = os.path.getmtime(path)
    return root, files


def state_file(data):
    key = re.sub(r"[^A-Za-z0-9_-]", "_", f"{data.get('session_id', '')}-{data.get('tool_use_id', '')}")
    return os.path.join(STATE, key)


def load_hook(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), os.path.join(HOOKS, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def before(data):
    root, files = changed_files(data.get("cwd") or os.getcwd())
    if root is None:
        return
    os.makedirs(STATE, exist_ok=True)
    with open(state_file(data), "w") as file:
        json.dump(files, file)


def after(data):
    try:
        with open(state_file(data)) as file:
            earlier = json.load(file)
        os.remove(state_file(data))
    except (OSError, ValueError):
        return
    command = (data.get("tool_input") or {}).get("command", "")
    if TOOLS.match(command):
        return
    _, files = changed_files(data.get("cwd") or os.getcwd())
    edited = sorted(
        path
        for path, mtime in files.items()
        if path.endswith(CHECKED) and earlier.get(path) != mtime and "/.git/" not in path
    )
    if not edited:
        return
    lines = [
        "Bash でファイルを書き換えた。ファイルの変更は Edit・Write で行う。書き換えたファイルに、Edit の後と同じ検査をかけた。",
        *edited,
    ]
    guard = load_hook("pre-edit-load-rules")
    rules = sorted({name for path in edited for name in guard.matching_rules(path)})
    if rules:
        lines.append("当たる決まり（まだ読んでいなければ Read で読む）: " + "、".join(rules))
    docs = load_hook("post-edit-check-docs")
    shell = load_hook("post-edit-check-shell")
    for path in edited:
        found = docs.check(path) if path.endswith(".md") else shell.check(path) if path.endswith(".sh") else []
        lines += [f"{path}:{n}: {m}" for n, m in found]
    print("\n".join(lines), file=sys.stderr)
    sys.exit(2)


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    if sys.argv[1:] == ["pre"]:
        before(data)
    else:
        after(data)


if __name__ == "__main__":
    main()
