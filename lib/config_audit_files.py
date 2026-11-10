import fnmatch
import functools
import os
import subprocess
from pathlib import Path

from loader import ROOT
from md_blocks import fence_marks, front_matter, heading_of
from script_io import fail


@functools.cache
def tracked_files():
    try:
        out = subprocess.run(["git", "-C", ROOT, "ls-files", "-z"], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        fail(f"git ls-files が通らない。{ROOT} が Git のリポジトリかを確かめる")
    return tuple(path for path in out.split("\0") if path)


def path_matches(path, pattern):
    if "/" not in pattern:
        return fnmatch.fnmatchcase(os.path.basename(path), pattern)
    parts, wants = path.split("/"), pattern.split("/")
    if wants[-1] == "**":
        wants = wants[:-1]
        parts = parts[: len(wants)] if len(parts) > len(wants) else []
    return len(parts) == len(wants) and all(fnmatch.fnmatchcase(part, want) for part, want in zip(parts, wants))


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
