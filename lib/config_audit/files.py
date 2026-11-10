import fnmatch
import functools
import os
import subprocess
from pathlib import Path

from loader import DOTCLAUDE, ROOT
from md_blocks import fence_marks, front_matter, heading_of, table_under
from script_io import fail

NAMING = os.path.join(ROOT, "docs", "config", "development.md")
LAYOUT = os.path.join(ROOT, "docs", "config", "layout.md")


@functools.cache
def tracked_files():
    try:
        out = subprocess.run(["git", "-C", ROOT, "ls-files", "-z"], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        fail(f"git ls-files が通らない。{ROOT} が Git のリポジトリかを確かめる")
    return tuple(path for path in out.split("\0") if path)


def place_matches(path, pattern):
    parts, wants = path.split("/"), pattern.split("/")
    if wants[-1] == "**":
        wants = wants[:-1]
        parts = parts[: len(wants)] if len(parts) > len(wants) else []
    return len(parts) == len(wants) and all(fnmatch.fnmatchcase(part, want) for part, want in zip(parts, wants))


def path_matches(path, pattern):
    if "/" not in pattern:
        return fnmatch.fnmatchcase(os.path.basename(path), pattern)
    return place_matches(path, pattern)


@functools.cache
def tracked(*patterns):
    return tuple(
        os.path.join(ROOT, path)
        for path in tracked_files()
        if any(path_matches(path, pattern) for pattern in patterns)
    )


@functools.cache
def read(path):
    return Path(path).read_text(encoding="utf-8")


def fields_of(path):
    return front_matter(read(path).split("\n")) or {}


def outside_code(path):
    lines = read(path).split("\n")
    return [(number, line) for number, (line, (mark, _)) in enumerate(zip(lines, fence_marks(lines)), 1) if mark is None]


def headings(path):
    return [(number, heading[1]) for number, line in outside_code(path) if (heading := heading_of(line)) and heading[0] == 2]


def rel(path):
    return os.path.relpath(path, ROOT)


def is_hook(path):
    return rel(path).startswith("dotclaude/hooks/")


def skill_names():
    return sorted(os.path.basename(os.path.dirname(path)) for path in tracked("dotclaude/skills/*/SKILL.md"))


def entry_kinds():
    found = {}
    for path in tracked("dotclaude/hooks/*.py"):
        found.setdefault(("hooks", os.path.splitext(os.path.basename(path))[0]), path)
    for path in tracked("scripts/*"):
        found.setdefault(("scripts", os.path.splitext(os.path.basename(path))[0]), path)
    for path in tracked("dotclaude/skills/*/scripts/*"):
        skill = os.path.relpath(path, DOTCLAUDE).split(os.sep)[1]
        found.setdefault(("skills", skill), os.path.join(DOTCLAUDE, "skills", skill, "SKILL.md"))
    return found


def entry_targets():
    targets = {}
    for (_, name), path in entry_kinds().items():
        targets.setdefault(name, path)
    return targets


def naming_table(heading, first_column):
    return table_under(read(NAMING).split("\n"), heading, first_column)


def layout_table(heading, first_column):
    return table_under(read(LAYOUT).split("\n"), heading, first_column) if os.path.exists(LAYOUT) else []
