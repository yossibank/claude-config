import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))

from transcripts import context_tokens  # noqa: E402

TAIL = 1_000_000
WINDOW = 200_000
LARGE_WINDOW = 1_000_000
SEPARATOR = " · "


def branch(cwd):
    env = {**os.environ, "GIT_OPTIONAL_LOCKS": "0"}
    for args in (["branch", "--show-current"], ["rev-parse", "--short", "HEAD"]):
        try:
            result = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True, timeout=1, env=env)
        except (OSError, subprocess.TimeoutExpired):
            return ""
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    return ""


def window_size(data):
    size = field(data, "context_window").get("context_window_size")
    if isinstance(size, int) and size > 0:
        return size
    model = str(field(data, "model").get("id", ""))
    return LARGE_WINDOW if "1m" in model.lower() else WINDOW


def field(data, name):
    value = data.get(name)
    return value if isinstance(value, dict) else {}


def context(data):
    path = data.get("transcript_path")
    if not path or not os.path.isfile(path):
        return ""
    tokens = context_tokens(path, TAIL)
    window = window_size(data)
    percent = min(100, tokens * 100 // window)
    mark = "🟢" if percent < 50 else "🟡" if percent < 80 else "🔴"
    return f"{mark} {tokens // 1000}k（{percent}%）"


def spending(data):
    cost = field(data, "cost")
    parts = []
    if isinstance(cost.get("total_cost_usd"), (int, float)):
        parts.append(f"💰 ${cost['total_cost_usd']:.2f}")
    added, removed = cost.get("total_lines_added"), cost.get("total_lines_removed")
    if isinstance(added, int) and isinstance(removed, int):
        parts.append(f"✏️ +{added}/-{removed}")
    return parts


def status_line(data):
    cwd = field(data, "workspace").get("current_dir") or data.get("cwd") or os.getcwd()
    name = branch(cwd)
    parts = [
        f"📂 {os.path.basename(cwd.rstrip('/'))}" + (f" 🌿 {name}" if name else ""),
        context(data),
        *spending(data),
        str(field(data, "model").get("display_name", "")),
    ]
    return SEPARATOR.join(part for part in parts if part)


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    if not isinstance(data, dict):
        return
    try:
        print(status_line(data))
    except (OSError, TypeError, ValueError):
        return


if __name__ == "__main__":
    main()
