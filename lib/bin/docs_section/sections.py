import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from md_blocks import fence_marks, heading_of  # noqa: E402
from md_doc import title_of  # noqa: E402
from script_io import fail, run_main  # noqa: E402


def main():
    if len(sys.argv) < 2:
        fail("使い方: docs-section.sh <Markdown のパス> [見出し]")
    path = sys.argv[1]
    want = sys.argv[2] if len(sys.argv) > 2 else ""
    try:
        lines = Path(path).read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        fail(f"読めない: {path}")
    depth = None
    titles = []
    for number, (line, (mark, _)) in enumerate(zip(lines, fence_marks(lines)), 1):
        heading = heading_of(line) if mark is None else None
        if heading:
            titles.append(heading[1])
        if heading and not want:
            print(f"{number}:{line}")
            continue
        if heading and depth is not None and heading[0] <= depth:
            return
        if heading and depth is None and title_of(heading[1]) == title_of(want):
            depth = heading[0]
        if depth is not None:
            print(line)
    if want and depth is None:
        fail(f"見出しが無い: {want}。候補: {' / '.join(titles) or 'なし'}")


if __name__ == "__main__":
    run_main(main)
