import datetime
import functools
import glob
import json
import os
from pathlib import Path

from dates import JST
from git import INNER_WORKTREES, WORKTREES


def projects_dir():
    return os.environ.get("CC_PROJECTS_DIR", os.path.expanduser("~/.claude/projects"))


def touched_since(pattern, start):
    return sorted(
        path for path in glob.glob(pattern) if datetime.datetime.fromtimestamp(os.path.getmtime(path), JST) >= start
    )


def sessions_since(projects, start):
    return touched_since(os.path.join(projects, "*", "*.jsonl"), start)


def subagents_since(projects, start):
    return touched_since(os.path.join(projects, "*", "*", "subagents", "*.jsonl"), start)


def subagents_of(session):
    return glob.glob(os.path.join(session.removesuffix(".jsonl"), "subagents", "*.jsonl"))


def parse_entry(line):
    try:
        entry = json.loads(line)
    except ValueError:
        return None
    return entry if isinstance(entry, dict) else None


def entries(path):
    with open(path, encoding="utf-8", errors="ignore") as file:
        for line in file:
            entry = parse_entry(line)
            if entry is not None:
                yield entry


@functools.cache
def repo_of(path):
    if path.startswith(WORKTREES):
        return path[len(WORKTREES) :].split("/")[0]
    if INNER_WORKTREES in path:
        return os.path.basename(path.split(INNER_WORKTREES)[0])
    while path not in ("", "/"):
        marker = os.path.join(path, ".git")
        if os.path.isfile(marker):
            gitdir = Path(marker).read_text(encoding="utf-8").removeprefix("gitdir:").strip()
            return os.path.basename(gitdir.split("/.git/worktrees/")[0])
        if os.path.isdir(marker):
            return os.path.basename(path)
        path = os.path.dirname(path)
    return ""


def tail_lines(path, limit, marker=None, chunk=4_000_000):
    with open(path, "rb") as file:
        file.seek(0, os.SEEK_END)
        position = file.tell()
        data = b""
        while position > 0 and len(data) < limit:
            step = min(chunk, position)
            position -= step
            file.seek(position)
            data = file.read(step) + data
            index = data.rfind(marker) if marker else -1
            if index >= 0:
                return data[data.rfind(b"\n", 0, index) + 1 :].decode("utf-8", "ignore").splitlines()
    return data.decode("utf-8", "ignore").splitlines()
