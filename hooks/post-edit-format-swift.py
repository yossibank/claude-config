import json
import os
import shutil
import subprocess
import sys


def repository_root(path):
    result = subprocess.run(
        ["git", "-C", os.path.dirname(path), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def pinned(root):
    mintfile = os.path.join(root, "Mintfile")
    if not os.path.isfile(mintfile):
        return False
    with open(mintfile) as file:
        return any("swiftformat" in line.lower() for line in file)


def main():
    data = json.load(sys.stdin)
    path = data.get("tool_input", {}).get("file_path", "")
    if not path.endswith(".swift") or not os.path.isfile(path):
        return
    root = repository_root(path)
    if not root or not os.path.isfile(os.path.join(root, ".swiftformat")):
        return
    if shutil.which("mint") is None or not pinned(root):
        return
    try:
        result = subprocess.run(
            ["mint", "run", "swiftformat", path],
            cwd=root,
            capture_output=True,
            text=True,
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        print("swiftformat が 60 秒で終わらなかった", file=sys.stderr)
        return
    if result.returncode != 0:
        print(f"swiftformat が失敗した：{result.stderr.strip()[-500:]}", file=sys.stderr)


if __name__ == "__main__":
    main()
