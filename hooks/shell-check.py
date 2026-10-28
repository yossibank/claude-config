import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from hook_io import read_payload, tool_input  # noqa: E402

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
    for number, line in enumerate(open(path, encoding="utf-8", errors="ignore").read().split("\n"), 1):
        if VAR_BEFORE_WIDE.search(line):
            found.append((number, "変数の直後に全角の文字がある。bash は変数名の一部とみなすので ${名前} で囲む"))
    return found


def main():
    if len(sys.argv) > 1:
        paths = sys.argv[1:]
    else:
        data = read_payload()
        if data is None:
            return
        paths = [tool_input(data).get("file_path", "")]
    report = []
    for path in map(os.path.abspath, filter(None, paths)):
        if path.endswith(".sh") and os.path.isfile(path):
            report += [f"{path}:{n}: {m}" for n, m in check(path)]
    if report:
        print("シェルスクリプトに直すところがある。", file=sys.stderr)
        print("\n".join(report), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
