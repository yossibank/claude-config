import json
import os
import re
import shlex
import subprocess
import sys

STATE_SH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "skills", "pr-create", "scripts", "state.sh")
GATED = re.compile(r"(^|[;&|]\s*)(git(\s+-C\s+\S+)?\s+push|gh\s+pr\s+create)\b")
SKIPPED = ("--tags", "--delete", "-d ", ":refs/")


def target_repo(command, cwd):
    words = shlex.split(command, posix=True) if command else []
    for i, word in enumerate(words[:-1]):
        if word == "-C" and words[i - 1:i] == ["git"]:
            return os.path.join(cwd, os.path.expanduser(words[i + 1]))
    return cwd


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)


def problems(repo):
    top = git(repo, "rev-parse", "--show-toplevel").stdout.strip()
    if not top:
        return []
    record = git(top, "rev-parse", "--path-format=absolute", "--git-path", "pr-checks").stdout.strip()
    try:
        rows = [line.split("\t") for line in open(record, encoding="utf-8").read().splitlines() if line]
    except OSError:
        rows = []
    if not rows:
        return ["pr-create の check.sh で通した確認が無い"]
    state = subprocess.run(["bash", STATE_SH, top], capture_output=True, text=True).stdout.strip()
    found = [f"通っていない確認: {row[1]}" for row in rows if row[0] != "OK"]
    found += [f"確認の後に変更がある: {row[1]}" for row in rows if len(row) > 2 and row[2] != state]
    return found


def main():
    if os.environ.get("CLAUDE_PR_GATE") == "off":
        return
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    command = (data.get("tool_input") or {}).get("command", "")
    if not GATED.search(command) or any(word in command for word in SKIPPED):
        return
    try:
        repo = target_repo(command, data.get("cwd") or os.getcwd())
    except ValueError:
        return
    found = problems(repo)
    if found:
        print(
            "push と PR の作成の前に、pr-create の手順の確認を通す（check.sh で通し直すか、要らない記録は check.sh <作業場所> --drop <名前> で外す）。\n"
            + "\n".join(found),
            file=sys.stderr,
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
