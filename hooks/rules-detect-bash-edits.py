import json
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import BASH_EDITED, git, git_root, hook_off, read_payload, remove_stale, safe_name, split_commands, tool_input  # noqa: E402
from loader import load_hook  # noqa: E402

STATE = os.path.join(tempfile.gettempdir(), "claude-bash-edits")
CHECKED = (".md", ".swift", ".sh", ".py", ".kt", ".kts", ".yml", ".yaml", ".json")
TOOLS = {"git", "make", "mint", "swiftformat", "pre-commit", "gh", "brew", "xcodebuild", "swift", "cd"}
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
    parts = split_commands(command)
    return bool(parts) and all(words[0] in TOOLS for words in parts)


def before(data):
    root, files = changed_files(data.get("cwd") or os.getcwd())
    if root is None:
        return
    os.makedirs(STATE, exist_ok=True)
    remove_stale(STATE, STALE)
    Path(state_file(data)).write_text(json.dumps({"root": root, "files": files}))


def after(data):
    try:
        earlier = json.loads(Path(state_file(data)).read_text())
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
    modes = {"pre": before, "post": after}
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode not in modes:
        print(f"rules-detect-bash-edits: 知らないモード「{mode}」。pre か post を渡す", file=sys.stderr)
        sys.exit(1)
    data = read_payload()
    if data is None:
        return
    modes[mode](data)


if __name__ == "__main__":
    main()
