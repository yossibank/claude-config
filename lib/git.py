import os
import subprocess

WORKTREES = os.path.expanduser("~/.claude/worktrees/")
INNER_WORKTREES = "/.claude/worktrees/"


def git(cwd, *args, timeout=10):
    try:
        return subprocess.run(["git", "--no-optional-locks", "-C", cwd, *args], capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None


def git_root(path):
    folder = path if os.path.isdir(path) else os.path.dirname(path) or "."
    while not os.path.isdir(folder) and os.path.dirname(folder) != folder:
        folder = os.path.dirname(folder)
    result = git(folder, "rev-parse", "--show-toplevel", timeout=5)
    return result.stdout.strip() if result and result.returncode == 0 else ""
