import datetime
import glob
import json
import os
import re

JST = datetime.timezone(datetime.timedelta(hours=9))
MONTH = re.compile(r"\d{4}-(0[1-9]|1[0-2])")


def to_jst(stamp):
    return datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone(JST)


def month_start(month):
    return datetime.datetime.strptime(month, "%Y-%m").replace(tzinfo=JST)


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
