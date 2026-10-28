import datetime
import glob
import json
import os

from months import JST


def projects_dir():
    return os.environ.get("CLAUDE_PROJECTS", os.path.expanduser("~/.claude/projects"))


def touched_since(pattern, start):
    return sorted(
        path for path in glob.glob(pattern) if datetime.datetime.fromtimestamp(os.path.getmtime(path), JST) >= start
    )


def entries(path):
    for line in open(path, encoding="utf-8", errors="ignore"):
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(entry, dict):
            yield entry
