import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "lib"))

from git import git_root  # noqa: E402
from hook_io import notify, read_payload, run_hook, tool_input  # noqa: E402

TIMEOUT = 10


def pinned(root):
    mintfile = os.path.join(root, "Mintfile")
    if not os.path.isfile(mintfile):
        return False
    with open(mintfile) as file:
        return any("swiftformat" in line.lower() for line in file if not line.lstrip().startswith("#"))


def main():
    data = read_payload()
    if data is None:
        return
    path = tool_input(data).get("file_path", "")
    if not path.endswith(".swift") or not os.path.isfile(path):
        return
    root = git_root(path)
    if not root or not os.path.isfile(os.path.join(root, ".swiftformat")):
        return
    if not pinned(root):
        return
    if shutil.which("mint") is None:
        notify("mint が見つからないので、swiftformat を走らせなかった")
        return
    try:
        result = subprocess.run(
            ["mint", "run", "swiftformat", path],
            cwd=root,
            capture_output=True,
            text=True,
            timeout=TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        notify(f"swiftformat が {TIMEOUT} 秒で終わらなかった")
        return
    if result.returncode != 0:
        notify(f"swiftformat が失敗した：{result.stderr.strip()[-500:]}")


if __name__ == "__main__":
    run_hook("swift-format", main)
