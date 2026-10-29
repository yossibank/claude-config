import json
import os
import re
import shlex
import sys

SEGMENT = re.compile(r"&&|\|\||;|\||\n")
SEPARATOR_CHARS = set(";&|()\n")
OFF_SEPARATOR = re.compile(r"[\s,]+")
EDIT_TOOLS = ("Edit", "Write", "MultiEdit", "NotebookEdit")


def read_payload():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return None
    return data if isinstance(data, dict) else None


def hook_off(name):
    return name in OFF_SEPARATOR.split(os.environ.get("CC_HOOKS_OFF", ""))


def tool_input(payload):
    value = payload.get("tool_input")
    return value if isinstance(value, dict) else {}


def split_commands(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars="();<>|&\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        tokens = list(lexer)
    except ValueError:
        return [part.split() for part in SEGMENT.split(command) if part.split()]
    parts = [[]]
    for token in tokens:
        if set(token) <= SEPARATOR_CHARS:
            parts.append([])
        else:
            parts[-1].append(token)
    return [words for words in parts if words]
