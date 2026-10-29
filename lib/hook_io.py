import json
import os
import re
import shlex
import sys

from hook_messages import GATE_FAILED

SEGMENT = re.compile(r"&&|\|\||;|\||\n")
SEPARATOR_CHARS = set(";&|()\n")
OFF_SEPARATOR = re.compile(r"[\s,]+")
FILE_EDIT_TOOLS = ("Edit", "Write", "MultiEdit")
EDIT_TOOLS = (*FILE_EDIT_TOOLS, "NotebookEdit")
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
PREFIX_VALUE_OPTIONS = {
    "builtin": set(),
    "command": set(),
    "env": {"-u"},
    "exec": {"-a"},
    "nice": {"-n"},
    "nohup": set(),
    "sudo": {"-C", "-D", "-g", "-p", "-R", "-T", "-U", "-u"},
    "time": set(),
    "timeout": {"-k", "-s"},
}
PREFIX_ARGUMENTS = {"timeout": 1}
GIT_VALUE_OPTIONS = {"-C", "-c", "--attr-source", "--config-env", "--exec-path", "--git-dir", "--namespace", "--work-tree"}


def read_payload():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return None
    return data if isinstance(data, dict) else None


def target_paths(suffix):
    if len(sys.argv) > 1:
        paths = sys.argv[1:]
    else:
        data = read_payload()
        paths = [tool_input(data).get("file_path", "")] if data else []
    return [path for path in map(os.path.abspath, filter(None, paths)) if path.endswith(suffix) and os.path.isfile(path)]


def block_on_findings(header, paths, check):
    report = [f"{path}:{n}: {m}" for path in paths for n, m in check(path)]
    if report:
        print(header + "\n" + "\n".join(report), file=sys.stderr)
        sys.exit(2)


def run_gate(name, main):
    try:
        main()
    except Exception as error:
        print(f"{GATE_FAILED}（{name}: {type(error).__name__}: {error}）。直すまでは CC_HOOKS_OFF={name} で外せる", file=sys.stderr)
        sys.exit(2)


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


def command_words(words):
    index = 0
    while index < len(words):
        if ASSIGNMENT.match(words[index]):
            index += 1
        elif os.path.basename(words[index]) in PREFIX_VALUE_OPTIONS:
            name = os.path.basename(words[index])
            index += 1
            while index < len(words) and words[index].startswith("-"):
                index += 2 if words[index] in PREFIX_VALUE_OPTIONS[name] else 1
            index += PREFIX_ARGUMENTS.get(name, 0)
        else:
            return [os.path.basename(words[index]), *words[index + 1 :]]
    return []


def git_subcommand(words):
    directories = []
    index = 1
    while index < len(words) and words[index].startswith("-"):
        if words[index] in GIT_VALUE_OPTIONS and index + 1 < len(words):
            if words[index] == "-C":
                directories.append(words[index + 1])
            index += 2
        else:
            index += 1
    return directories, words[index:]
