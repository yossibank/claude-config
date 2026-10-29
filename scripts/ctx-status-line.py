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


def context(data):
    path = data.get("transcript_path")
    if not path or not os.path.isfile(path):
        return ""
    tokens = context_tokens(path, TAIL)
    model = str((data.get("model") or {}).get("id", ""))
    window = LARGE_WINDOW if "1m" in model.lower() else WINDOW
    percent = min(100, tokens * 100 // window)
    mark = "🟢" if percent < 50 else "🟡" if percent < 80 else "🔴"
    return f"{mark} {tokens // 1000}k（{percent}%）"


def spending(data):
    cost = data.get("cost") or {}
    parts = []
    if isinstance(cost.get("total_cost_usd"), (int, float)):
        parts.append(f"💰 ${cost['total_cost_usd']:.2f}")
    added, removed = cost.get("total_lines_added"), cost.get("total_lines_removed")
    if isinstance(added, int) and isinstance(removed, int):
        parts.append(f"✏️ +{added}/-{removed}")
    return parts


def status_line(data):
    cwd = (data.get("workspace") or {}).get("current_dir") or data.get("cwd") or os.getcwd()
    name = branch(cwd)
    parts = [
        f"📂 {os.path.basename(cwd.rstrip('/'))}" + (f" 🌿 {name}" if name else ""),
        context(data),
        *spending(data),
        str((data.get("model") or {}).get("display_name", "")),
    ]
    return SEPARATOR.join(part for part in parts if part)


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    if isinstance(data, dict):
        print(status_line(data))


if __name__ == "__main__":
    main()
