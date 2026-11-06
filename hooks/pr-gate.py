import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from git import git_root  # noqa: E402
from hook_io import command_words, git_subcommand, notify, read_payload, run_gate, split_commands, tool_input  # noqa: E402
from hook_messages import PR_UNCHECKED  # noqa: E402
from loader import ROOT  # noqa: E402

CHECK_SH = os.path.join(ROOT, "skills", "pr-create", "scripts", "run-check.sh")
PUSH_SKIPPED = {"--delete", "-d"}
SHELLS = {"bash", "sh", "zsh"}
UNRESOLVED = object()
SUBSTITUTED = re.compile(r"\$SUB(\d+)")
HEREDOC = re.compile(r"<<(-?)[ \t]*(?:'([^'\n]*)'|\"([^\"\n]*)\"|([A-Za-z0-9_.-]+))")
COMMENT_AFTER = set(" \t;&|(")


def heredocs(line, quote):
    found = []
    index = 0
    while index < len(line):
        char = line[index]
        if quote == "'":
            quote = None if char == "'" else quote
        elif char == "\\":
            index += 2
            continue
        elif quote == '"':
            quote = None if char == '"' else quote
        elif char in "'\"":
            quote = char
        elif char == "#" and (index == 0 or line[index - 1] in COMMENT_AFTER):
            break
        elif line.startswith("<<<", index):
            index += 3
            continue
        elif match := HEREDOC.match(line, index):
            strip, single, double, bare = match.groups()
            quoted = single is not None or double is not None
            found.append((strip == "-", next(word for word in (single, double, bare) if word is not None), quoted))
            index = match.end()
            continue
        index += 1
    return found, quote


def without_quoted_heredocs(command):
    kept = []
    ends = []
    quote = None
    for line in command.split("\n"):
        if ends:
            strip, end, quoted = ends[0]
            if (line.lstrip("\t") if strip else line) == end:
                ends.pop(0)
            elif not quoted:
                kept.append(line)
            continue
        kept.append(line)
        ends, quote = heredocs(line, quote)
    return command if ends else "\n".join(kept)


def shell_command(words):
    if words[0] not in SHELLS:
        return None
    for index, word in enumerate(words[1:-1], 1):
        if word.startswith("-") and not word.startswith("--") and "c" in word:
            return words[index + 1]
    return None


def substitutions(command):
    outer = []
    inners = []
    quote = None
    index = 0
    while index < len(command):
        char = command[index]
        if quote == "'":
            quote = None if char == "'" else quote
            outer.append(char)
            index += 1
        elif char == "\\":
            outer.append(command[index : index + 2])
            index += 2
        elif char == "'" and quote is None:
            quote = "'"
            outer.append(char)
            index += 1
        elif char == '"':
            quote = None if quote == '"' else '"'
            outer.append(char)
            index += 1
        elif command.startswith("$(", index) or char == "`":
            end = closing(command, index)
            start = index + (2 if char == "$" else 1)
            inners.append(command[start:end])
            outer.append(f"$SUB{len(inners) - 1}")
            index = end + 1
        else:
            outer.append(char)
            index += 1
    return "".join(outer), inners


def closing(command, start):
    if command[start] == "`":
        end = command.find("`", start + 1)
        return len(command) if end < 0 else end
    depth = 0
    quote = None
    index = start + 1
    while index < len(command):
        char = command[index]
        if char == "\\" and quote != "'":
            index += 2
            continue
        if quote:
            quote = None if char == quote else quote
        elif char in "'\"":
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return len(command)


def resolve(base, path):
    home = os.path.expanduser("~")
    path = os.path.expanduser(path).replace("${HOME}", home).replace("$HOME", home)
    if "$" in path or "`" in path:
        return UNRESOLVED
    if os.path.isabs(path):
        return path
    return UNRESOLVED if base is UNRESOLVED else os.path.join(base, path)


def push_gated(args):
    if any(word in PUSH_SKIPPED or word.startswith(":") for word in args):
        return False
    positional = [word for word in args if not word.startswith("-")]
    return "--tags" not in args or len(positional) > 1


def gated_repo(command, cwd):
    command, inners = substitutions(without_quoted_heredocs(command))
    for parts in split_commands(command):
        for word in parts:
            for number in SUBSTITUTED.findall(word):
                repo = gated_repo(inners[int(number)], cwd) if int(number) < len(inners) else None
                if repo is not None:
                    return repo
        words = command_words(parts)
        if words[:1] == ["cd"] and len(words) > 1:
            cwd = resolve(cwd, words[1])
            continue
        inner = shell_command(words) if words else None
        if inner is not None:
            repo = gated_repo(inner, cwd)
            if repo is not None:
                return repo
            continue
        if words[:2] == ["gh", "pr"] and words[2:3] in (["create"], ["new"]):
            return cwd
        if words[:1] != ["git"]:
            continue
        directories, rest = git_subcommand(words)
        repo = cwd
        for directory in directories:
            repo = resolve(repo, directory)
        if rest[:1] == ["push"] and push_gated(rest[1:]):
            return repo
    return None


def problems(repo):
    top = git_root(repo)
    if not top:
        return []
    try:
        result = subprocess.run(["bash", CHECK_SH, top, "--status"], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as error:
        notify(f"pr-gate: run-check.sh を走らせられなかったので、確かめずに通す（{type(error).__name__}）")
        return []
    if result.returncode == 0:
        return []
    found = [line[3:] for line in result.stdout.splitlines() if line.startswith("NG ")]
    if found or result.stdout.strip():
        return found or [result.stdout.strip()]
    reason = result.stderr.strip().splitlines()[-1:]
    return [f"run-check.sh が失敗した（終了コード {result.returncode}）" + "".join(f": {line}" for line in reason)]


def main():
    data = read_payload()
    if data is None:
        return
    repo = gated_repo(tool_input(data).get("command", ""), data.get("cwd") or os.getcwd())
    if repo is None:
        return
    if repo is UNRESOLVED:
        print(f"{PR_UNCHECKED}、どのリポジトリかを確かめられるようにする。cd と git -C の先に変数やコマンド置換を使わず、パスを直接書く", file=sys.stderr)
        sys.exit(2)
    found = problems(repo)
    if found:
        print(
            f"{PR_UNCHECKED}、pr-create の手順の確認を通す（run-check.sh で通し直すか、要らない記録は run-check.sh <ワークツリー> --drop <名前> で外す）。\n"
            + "\n".join(found),
            file=sys.stderr,
        )
        sys.exit(2)


if __name__ == "__main__":
    run_gate("pr-gate", main)
