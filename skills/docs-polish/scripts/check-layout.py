import glob
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from md_blocks import fence_marks, front_matter_end  # noqa: E402
from script_io import fail  # noqa: E402

HEADING = re.compile(r"^(#{2,6})\s+(.*)$")
LIST = re.compile(r"^\s*([-*+]|\d+\.)\s")
PROSE_LIMIT = 4
HUMAN_DOCS = ("README.md", "docs/**/*.md", "spec/**/*.md")


def human_docs(folder):
    found = set()
    for pattern in HUMAN_DOCS:
        found.update(glob.glob(os.path.join(folder, pattern), recursive=True))
    return sorted(found)


def sections(lines):
    start = (front_matter_end(lines) or -1) + 1
    current = {"line": 1, "title": "冒頭", "prose": 0, "shaped": False}
    found = [current]
    for number, (line, (mark, language)) in enumerate(zip(lines, fence_marks(lines)), 1):
        if number <= start:
            continue
        if mark == "open":
            current["shaped"] = current["shaped"] or bool(language)
            continue
        if mark in ("code", "close"):
            continue
        heading = HEADING.match(line)
        if heading:
            current = {"line": number, "title": heading.group(2).strip(), "prose": 0, "shaped": False}
            found.append(current)
        elif line.startswith(("|", ">", "![", "[![")) or LIST.match(line) or line.lstrip().startswith("<"):
            current["shaped"] = True
        elif line.strip() and not line.startswith("#"):
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
    bad = False
    for path in paths:
        found = list(problems(path))
        for number, message in found:
            print(f"NG {path}:{number} {message}")
        if not found:
            print(f"OK {path}")
        bad = bad or bool(found)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
