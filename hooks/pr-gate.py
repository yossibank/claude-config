import os
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from git import git_root  # noqa: E402
from hook_io import command_words, git_subcommand, read_payload, run_gate, split_commands, tool_input  # noqa: E402
from hook_messages import PR_UNCHECKED  # noqa: E402
from loader import ROOT  # noqa: E402

CHECK_SH = os.path.join(ROOT, "skills", "pr-create", "scripts", "run-check.sh")
PUSH_SKIPPED = {"--tags", "--delete", "-d"}
SHELLS = {"bash", "sh", "zsh"}


def shell_command(words):
    if words[0] not in SHELLS:
        return None
    for index, word in enumerate(words[1:-1], 1):
        if word.startswith("-") and not word.startswith("--") and "c" in word:
            return words[index + 1]
    return None


def gated_repo(command, cwd):
    for parts in split_commands(command):
        words = command_words(parts)
        if words[:1] == ["cd"] and len(words) > 1:
            cwd = os.path.join(cwd, os.path.expanduser(words[1]))
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
            repo = os.path.join(repo, os.path.expanduser(directory))
        if rest[:1] == ["push"] and not any(word in PUSH_SKIPPED or word.startswith(":") for word in rest[1:]):
            return repo
    return None


def problems(repo):
    top = git_root(repo)
    if not top:
        return []
    try:
        result = subprocess.run(["bash", CHECK_SH, top, "--status"], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"pr-gate: run-check.sh を走らせられなかったので、確かめずに通す（{type(error).__name__}）", file=sys.stderr)
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
