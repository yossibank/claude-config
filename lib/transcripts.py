import datetime
import glob
import json
import os

from dates import JST


def projects_dir():
    return os.environ.get("CLAUDE_PROJECTS", os.path.expanduser("~/.claude/projects"))


def touched_since(pattern, start):
    return sorted(
        path for path in glob.glob(pattern) if datetime.datetime.fromtimestamp(os.path.getmtime(path), JST) >= start
    )


def parse_entry(line):
    try:
        entry = json.loads(line)
    except ValueError:
        return None
    return entry if isinstance(entry, dict) else None


def entries(path):
    for line in open(path, encoding="utf-8", errors="ignore"):
        entry = parse_entry(line)
        if entry is not None:
            yield entry


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
