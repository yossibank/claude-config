import glob
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "..", "lib"))

from md_blocks import fence_marks  # noqa: E402
from md_doc import body_start, kind  # noqa: E402
from script_io import fail, finish, run_main  # noqa: E402

HEADING = re.compile(r"^(#{2,6})\s+(.*)$")
SHAPED_KINDS = ("table", "list", "quote")
SHAPED_STARTS = ("![", "[![", "<")
PROSE_LIMIT = 4
HUMAN_DOCS = ("README.md", "docs/**/*.md", "spec/**/*.md")
DOC_FOLDERS = ("docs", "spec")


def human_docs(folder):
    found = set()
    patterns = ("**/*.md",) if os.path.basename(os.path.abspath(folder)) in DOC_FOLDERS else HUMAN_DOCS
    for pattern in patterns:
        found.update(glob.glob(os.path.join(folder, pattern), recursive=True))
    return sorted(found)


def sections(lines):
    start = body_start(lines)
    current = {"line": 1, "title": "", "prose": 0, "shaped": True}
    found = []
    for number, (line, (mark, language)) in enumerate(zip(lines[start:], fence_marks(lines[start:])), start + 1):
        if mark == "open":
            current["shaped"] = current["shaped"] or bool(language)
            continue
        if mark in ("code", "close"):
            continue
        heading = HEADING.match(line)
        what = kind(line.strip())
        if heading:
            current = {"line": number, "title": heading.group(2).strip(), "prose": 0, "shaped": False}
            found.append(current)
        elif (what in SHAPED_KINDS and line.strip().strip(">").strip()) or line.lstrip().startswith(SHAPED_STARTS):
            current["shaped"] = True
        elif what == "body":
            current["prose"] += 1
    return found


def problems(path):
    with open(path, encoding="utf-8") as file:
        lines = file.read().split("\n")
    for section in sections(lines):
        if section["prose"] >= PROSE_LIMIT and not section["shaped"]:
            yield section["line"], f"{section['title']}: 文が {section['prose']} 行続き、表・箇条書き・図が無い"


def main():
    if len(sys.argv) < 2:
        fail("使い方: check-layout.py <ファイルかフォルダ>…")
    paths = []
    for arg in sys.argv[1:]:
        if os.path.isdir(arg):
            paths += human_docs(arg)
        elif os.path.isfile(arg):
            paths.append(arg)
        else:
            fail(f"ファイルもフォルダも無い: {arg}")
    if not paths:
        fail("人が読む文書（README・docs・spec）が無い")
    lines = []
    for path in paths:
        found = [f"NG {path}:{number} {message}" for number, message in problems(path)]
        lines += found or [f"OK {path}"]
    finish(lines)


if __name__ == "__main__":
    run_main(main)
