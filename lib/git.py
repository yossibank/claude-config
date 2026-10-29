import os
import subprocess


def git(cwd, *args, timeout=10):
    try:
        return subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None


def git_root(path):
    folder = path if os.path.isdir(path) else os.path.dirname(path) or "."
    result = git(folder, "rev-parse", "--show-toplevel", timeout=5)
    return result.stdout.strip() if result and result.returncode == 0 else ""
