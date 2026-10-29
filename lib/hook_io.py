import json
import os
import re
import subprocess
import sys
import time

SEGMENT = re.compile(r"&&|\|\||;|\|")
OFF_SEPARATOR = re.compile(r"[\s,]+")
EDIT_TOOLS = ("Edit", "Write", "MultiEdit", "NotebookEdit")
RULES_UNREAD = "この編集に当たる決まりを、この会話でまだ読んでいない"
BASH_EDITED = "Bash でファイルを書き換えた"
PR_UNCHECKED = "push と PR の作成の前に"


def read_payload():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return None
    return data if isinstance(data, dict) else None


def hook_off(name):
    return name in OFF_SEPARATOR.split(os.environ.get("CLAUDE_HOOKS_OFF", ""))


def tool_input(payload):
    value = payload.get("tool_input")
    return value if isinstance(value, dict) else {}


def split_commands(command):
    return SEGMENT.split(command)


def git(cwd, *args, timeout=10):
    try:
        return subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None


def git_root(path):
    folder = path if os.path.isdir(path) else os.path.dirname(path) or "."
    result = git(folder, "rev-parse", "--show-toplevel", timeout=5)
    return result.stdout.strip() if result and result.returncode == 0 else ""


def safe_name(text):
    return re.sub(r"[^A-Za-z0-9_-]", "_", text)


def remove_stale(folder, age):
    try:
        names = os.listdir(folder)
    except OSError:
        return
    for name in names:
        path = os.path.join(folder, name)
        try:
            if time.time() - os.path.getmtime(path) > age:
                if os.path.isdir(path):
                    for child in os.listdir(path):
                        os.remove(os.path.join(path, child))
                    os.rmdir(path)
                else:
                    os.remove(path)
        except OSError:
            continue

