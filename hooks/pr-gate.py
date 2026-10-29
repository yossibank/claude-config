import os
import shlex
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import git_root, read_payload, split_commands, tool_input  # noqa: E402
from hook_stops import PR_UNCHECKED  # noqa: E402

CHECK_SH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "skills", "pr-create", "scripts", "run-check.sh")
PUSH_SKIPPED = {"--tags", "--delete", "-d"}


def gated_repo(command, cwd):
    for part in split_commands(command):
        try:
            words = shlex.split(part, posix=True)
        except ValueError:
            continue
        if words[:1] == ["cd"] and len(words) > 1:
            cwd = os.path.join(cwd, os.path.expanduser(words[1]))
            continue
        if words[:3] == ["gh", "pr", "create"]:
            return cwd
        if words[:1] != ["git"]:
            continue
        repo = cwd
        rest = words[1:]
        if rest[:1] == ["-C"] and len(rest) > 1:
            repo = os.path.join(cwd, os.path.expanduser(rest[1]))
            rest = rest[2:]
        if rest[:1] == ["push"] and not any(word in PUSH_SKIPPED or word.startswith(":") for word in rest[1:]):
            return repo
    return None


def problems(repo):
    top = git_root(repo)
    if not top:
        return []
    try:
        result = subprocess.run(["bash", CHECK_SH, top, "--status"], capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
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
            f"{PR_UNCHECKED}、pr-create の手順の確認を通す（run-check.sh で通し直すか、要らない記録は run-check.sh <作業場所> --drop <名前> で外す）。\n"
            + "\n".join(found),
            file=sys.stderr,
        )
        sys.exit(2)


if __name__ == "__main__":
    main()
