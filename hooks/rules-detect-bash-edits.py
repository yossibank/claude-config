import hashlib
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from git import git, git_root  # noqa: E402
from hook_io import command_words, hook_off, notify, read_payload, split_commands, tool_input  # noqa: E402
from hook_messages import BASH_EDITED  # noqa: E402
from hook_state import prepare_state, safe_name, state_folder  # noqa: E402
from loader import load_hook  # noqa: E402

STATE = state_folder("bash-edits")
CHECKED = (".md", ".swift", ".sh", ".py", ".kt", ".kts", ".yml", ".yaml", ".json")
TOOLS = {"git", "make", "mint", "swiftformat", "pre-commit", "gh", "brew", "xcodebuild", "swift", "cd"}
STALE = 24 * 60 * 60
REDIRECT_CHARS = set("<>|&")


def changed_files(cwd):
    root = git_root(cwd)
    if not root:
        return None, {}
    result = git(root, "status", "--porcelain", "-z", "--untracked-files=all")
    if result is None:
        notify("rules-detect-bash-edits: git status が時間切れになったので、Bash での書き換えを確かめなかった")
    if not result or result.returncode:
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


def edit_mark(path):
    return os.path.join(STATE, "edited-" + hashlib.sha256(os.path.realpath(path).encode()).hexdigest())


def edited_since(path, started):
    try:
        return os.path.getmtime(edit_mark(path)) >= started
    except OSError:
        return False


def redirect_targets(command, cwd):
    targets = set()
    for words in split_commands(command):
        for index, word in enumerate(words[:-1]):
            target = words[index + 1]
            if ">" not in word or not set(word) <= REDIRECT_CHARS or target.startswith("/dev/"):
                continue
            if word.endswith("&") and (target.isdigit() or target == "-"):
                continue
            targets.add(os.path.realpath(os.path.join(cwd, os.path.expanduser(target))))
    return targets


def only_tools(command):
    parts = [command_words(words) for words in split_commands(command)]
    return bool(parts) and all(words[:1] and words[0] in TOOLS for words in parts)


def cwd_of(data):
    return data.get("cwd") or os.getcwd()


def before(data):
    command = tool_input(data).get("command", "")
    if only_tools(command) and not redirect_targets(command, cwd_of(data)):
        return
    root, files = changed_files(cwd_of(data))
    if root is None:
        return
    prepare_state(STATE, STALE)
    Path(state_file(data)).write_text(json.dumps({"root": root, "files": files}))


def after(data):
    try:
        started = os.path.getmtime(state_file(data))
        earlier = json.loads(Path(state_file(data)).read_text())
        os.remove(state_file(data))
    except (OSError, ValueError):
        return
    command = tool_input(data).get("command", "")
    if not isinstance(earlier, dict) or "root" not in earlier:
        return
    targets = redirect_targets(command, cwd_of(data)) if only_tools(command) else None
    if targets is not None and not targets:
        return
    _, files = changed_files(earlier["root"])
    edited = sorted(
        path
        for path, mtime in files.items()
        if path.endswith(CHECKED)
        and earlier["files"].get(path) != mtime
        and "/.git/" not in path
        and not edited_since(path, started)
        and (targets is None or os.path.realpath(path) in targets)
    )
    if not edited:
        return
    lines = [
        f"{BASH_EDITED}。ファイルの変更は Edit・Write で行う。書き換えたファイルに、Edit の後と同じ検査をかけた。",
        *edited,
    ]
    if not hook_off("rules-require-read"):
        guard = load_hook("rules-require-read")
        rules = sorted({name for path in edited for name in guard.matching_rules(path, earlier["root"])})
        if rules:
            lines.append("当たる決まり（まだ読んでいなければ Read で読む）: " + "、".join(rules))
    checks = {".md": "docs-check", ".sh": "shell-check"}
    for path in edited:
        name = next((hook for suffix, hook in checks.items() if path.endswith(suffix)), None)
        if name and not hook_off(name):
            lines += [f"{path}:{n}: {m}" for n, m in load_hook(name).check(path)]
    print("\n".join(lines), file=sys.stderr)
    sys.exit(2)


def mark_edit(data):
    path = tool_input(data).get("file_path", "")
    if not path:
        return
    prepare_state(STATE, STALE)
    Path(edit_mark(path)).touch()


def main():
    modes = {"pre": before, "post": after, "edit": mark_edit}
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode not in modes:
        print(f"rules-detect-bash-edits: 知らないモード「{mode}」。pre・post・edit のどれかを渡す", file=sys.stderr)
        sys.exit(1)
    data = read_payload()
    if data is None:
        return
    modes[mode](data)


if __name__ == "__main__":
    main()
