import json
import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import git, git_root, hook_off, read_payload, remove_stale, safe_name, split_commands, tool_input  # noqa: E402
from hook_stops import BASH_EDITED  # noqa: E402
from modules import load_hook  # noqa: E402

STATE = os.path.join(tempfile.gettempdir(), "claude-bash-edits")
CHECKED = (".md", ".swift", ".sh", ".py", ".kt", ".kts", ".yml", ".yaml", ".json")
TOOLS = re.compile(r"^\s*(git|make|mint|swiftformat|pre-commit|gh|brew|xcodebuild|swift|cd)\b")
STALE = 24 * 60 * 60


def changed_files(cwd):
    result = git(cwd, "status", "--porcelain", "-z", "--untracked-files=all")
    root = git_root(cwd)
    if not result or result.returncode or not root:
        return None, {}
    files = {}
    entries = iter(result.stdout.split("\0"))
    for entry in entries:
        if entry[:1] in ("R", "C"):
            next(entries, None)
        path = os.path.join(root, entry[3:])
        if entry and os.path.isfile(path):
            files[path] = os.path.getmtime(path)
    return root, files


def state_file(data):
    return os.path.join(STATE, safe_name(f"{data.get('session_id', '')}-{data.get('tool_use_id', '')}"))


def only_tools(command):
    parts = [part for part in split_commands(command) if part.strip()]
    return bool(parts) and all(TOOLS.match(part) for part in parts)


def before(data):
    root, files = changed_files(data.get("cwd") or os.getcwd())
    if root is None:
        return
    os.makedirs(STATE, exist_ok=True)
    remove_stale(STATE, STALE)
    with open(state_file(data), "w") as file:
        json.dump({"root": root, "files": files}, file)


def after(data):
    try:
        with open(state_file(data)) as file:
            earlier = json.load(file)
        os.remove(state_file(data))
    except (OSError, ValueError):
        return
    command = tool_input(data).get("command", "")
    if only_tools(command) or not isinstance(earlier, dict) or "root" not in earlier:
        return
    _, files = changed_files(earlier["root"])
    edited = sorted(
        path
        for path, mtime in files.items()
        if path.endswith(CHECKED) and earlier["files"].get(path) != mtime and "/.git/" not in path
    )
    if not edited:
        return
    lines = [
        f"{BASH_EDITED}。ファイルの変更は Edit・Write で行う。書き換えたファイルに、Edit の後と同じ検査をかけた。",
        *edited,
    ]
    if not hook_off("rules-require-read"):
        guard = load_hook("rules-require-read")
        rules = sorted({name for path in edited for name in guard.matching_rules(path)})
        if rules:
            lines.append("当たる決まり（まだ読んでいなければ Read で読む）: " + "、".join(rules))
    checks = {".md": "docs-check", ".sh": "shell-check"}
    for path in edited:
        name = next((hook for suffix, hook in checks.items() if path.endswith(suffix)), None)
        if name and not hook_off(name):
            lines += [f"{path}:{n}: {m}" for n, m in load_hook(name).check(path)]
    print("\n".join(lines), file=sys.stderr)
    sys.exit(2)


def main():
    data = read_payload()
    if data is None:
        return
    if sys.argv[1:] == ["pre"]:
        before(data)
    else:
        after(data)


if __name__ == "__main__":
    main()
