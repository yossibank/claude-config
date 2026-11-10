import json
import os
import re

from config_audit.files import read, tracked
from hook_io import FILE_EDIT_TOOLS
from loader import DOTCLAUDE

SETTINGS = os.path.join(DOTCLAUDE, "settings.json")
HOOK_NAME = re.compile(r"\.claude/hooks/run\.sh\\?\"? ([A-Za-z0-9_-]+)")
EVENT_ORDER = ["PreToolUse", "PostToolUse"]
PERMISSION = re.compile(r"^(\w+)(?:\((.*)\))?$")


def hook_groups():
    return json.loads(read(SETTINGS)).get("hooks", {})


def check_settings():
    path = SETTINGS
    for group in hook_groups().values():
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


def check_hook_registered():
    commands = [hook.get("command", "") for group in hook_groups().values() for entry in group for hook in entry.get("hooks", [])]
    registered = {name for command in commands for name in HOOK_NAME.findall(command)}
    for path in tracked("dotclaude/hooks/*.py"):
        name = os.path.splitext(os.path.basename(path))[0]
        if name not in registered:
            yield path, 1, f"settings.json に登録が無いフック: {name}"


def first_unsorted(items, key=None):
    return next((after for before, after in zip(items, items[1:]) if (key or str)(before) > (key or str)(after)), None)


def permission_key(permission):
    found = PERMISSION.match(permission)
    return (found.group(1), found.group(2) or "") if found else (permission, "")


def check_settings_order():
    data = json.loads(read(SETTINGS))
    allow = first_unsorted(data.get("permissions", {}).get("allow", []), permission_key)
    if allow:
        yield SETTINGS, 1, f"許可は道具の名前の順、同じ道具はコマンドと引数の順に並べる: {allow}"
    events = [event for event in data.get("hooks", {}) if event in EVENT_ORDER]
    if events != [event for event in EVENT_ORDER if event in events]:
        yield SETTINGS, 1, f"フックのイベントは {' → '.join(EVENT_ORDER)} の順に並べる"
    for event, group in data.get("hooks", {}).items():
        matcher = first_unsorted([entry.get("matcher") or "" for entry in group])
        if matcher is not None:
            yield SETTINGS, 1, f"{event} の matcher は名前の順に並べる: {matcher}"
        for entry in group:
            names = [(HOOK_NAME.findall(hook.get("command", "")) or [""])[0] for hook in entry.get("hooks", [])]
            name = first_unsorted(names)
            if name is not None:
                yield SETTINGS, 1, f"{event} の {entry.get('matcher')} のフックは名前の順に並べる: {name}"
