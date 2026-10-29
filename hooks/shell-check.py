import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import block_on_findings, target_paths  # noqa: E402

VAR_BEFORE_WIDE = re.compile(r"\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]")


def check(path):
    found = []
    try:
        result = subprocess.run(["bash", "-n", path], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        result = None
    if result and result.returncode:
        reason = result.stderr.strip().splitlines()
        found.append((1, "bash -n が通らない" + (f": {reason[-1]}" if reason else "")))
    for number, line in enumerate(Path(path).read_text(encoding="utf-8", errors="ignore").split("\n"), 1):
        if VAR_BEFORE_WIDE.search(line):
            found.append((number, "変数の直後に全角の文字がある。bash は変数名の一部とみなすので ${名前} で囲む"))
    return found


def main():
    block_on_findings("シェルスクリプトに直すところがある。", target_paths(".sh"), check)


if __name__ == "__main__":
    main()
