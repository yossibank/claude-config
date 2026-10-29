#!/bin/bash
set -euo pipefail

[[ $# -ge 1 ]] || { echo "NG 使い方: $(basename "$0") <Markdown のパス> [見出し]"; exit 1; }

exec python3 -I - "$(dirname "$0")/../lib" "$@" <<'EOF'
import re
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])

from md_blocks import fence_marks  # noqa: E402

HEADING = re.compile(r"^(#+) (.*)$")


def main():
    path = sys.argv[2]
    want = sys.argv[3] if len(sys.argv) > 3 else ""
    try:
        lines = Path(path).read_text(encoding="utf-8").splitlines()
    except OSError:
        print(f"NG 読めない: {path}")
        sys.exit(1)
    depth = None
    for number, (line, (mark, _)) in enumerate(zip(lines, fence_marks(lines)), 1):
        heading = HEADING.match(line) if mark is None else None
        if heading and not want:
            print(f"{number}:{line}")
            continue
        if heading and depth is not None and len(heading.group(1)) <= depth:
            return
        if heading and depth is None and heading.group(2) == want:
            depth = len(heading.group(1))
        if depth is not None:
            print(line)
    if want and depth is None:
        print(f"NG 見出しが無い: {want}")
        sys.exit(1)


if __name__ == "__main__":
    main()
EOF
