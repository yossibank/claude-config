import datetime
import glob
import json
import os
import re
import sys

JST = datetime.timezone(datetime.timedelta(hours=9))
CUE = re.compile(
    r"ではなく|じゃなく|違う|ちがう|やめ|しないで|外して|戻して|消して|不要|いらない|要らない|"
    r"おかしい|揃えて|そろえて|統一|勝手に|聞いて|前も|毎回|何度も"
)
WIDTH = 120
APPS = os.path.expanduser("~/Applications")
PREFIX = APPS.replace("/", "-") + "-"


def fail(message):
    print(f"NG {message}")
    sys.exit(1)


def text_of(content):
    if isinstance(content, list):
        content = " ".join(part.get("text", "") for part in content if isinstance(part, dict) and part.get("type") == "text")
    return content if isinstance(content, str) else ""


def place_of(entry):
    cwd = entry.get("cwd", "").split("/.claude/worktrees/")[0]
    return os.path.relpath(cwd, APPS).replace("/", "-") if cwd.startswith(APPS + "/") else ""


def clip(text):
    match = CUE.search(text)
    begin = max(0, match.start() - 40) if match else 0
    return ("…" if begin else "") + text[begin : begin + WIDTH]


def main():
    if len(sys.argv) < 2 or not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", sys.argv[1]):
        fail("使い方: collect.py <YYYY-MM>")

    month = sys.argv[1]
    projects = os.environ.get("CLAUDE_PROJECTS", os.path.expanduser("~/.claude/projects"))
    start = datetime.datetime.strptime(month, "%Y-%m").replace(tzinfo=JST)

    print(f"# {month} の手直しの材料\n")
    print("## feedback のメモリ\n")
    memories = 0
    for path in sorted(glob.glob(os.path.join(projects, "*", "memory", "*.md"))):
        text = open(path, encoding="utf-8", errors="ignore").read()
        if not re.search(r"^\s*type:\s*feedback\s*$", text, re.M):
            continue
        description = re.search(r"^description:\s*(.+)$", text, re.M)
        project = os.path.basename(os.path.dirname(os.path.dirname(path)))
        if not project.startswith(PREFIX):
            continue
        repo = project[len(PREFIX):].split("--claude-worktrees-")[0]
        memories += 1
        print(f"- {repo}／{os.path.basename(path)}：{description.group(1).strip() if description else ''}")
    if not memories:
        print("なし")

    print("\n## 手直しの言葉を含む人の文\n")
    seen = set()
    found = 0
    for path in sorted(glob.glob(os.path.join(projects, "*", "*.jsonl"))):
        if datetime.datetime.fromtimestamp(os.path.getmtime(path), JST) < start:
            continue
        for line in open(path, encoding="utf-8", errors="ignore"):
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("type") != "user" or entry.get("isSidechain") or not entry.get("timestamp"):
                continue
            when = datetime.datetime.fromisoformat(entry["timestamp"].replace("Z", "+00:00")).astimezone(JST)
            if when.strftime("%Y-%m") != month:
                continue
            text = text_of(entry.get("message", {}).get("content"))
            if not text or text.lstrip().startswith("<") or len(text) > 400 or not CUE.search(text):
                continue
            place = place_of(entry)
            if not place:
                continue
            flat = " ".join(text.split())
            if flat in seen:
                continue
            seen.add(flat)
            found += 1
            print(f"- {when:%m-%d} {place}：{clip(flat)}")
    if not found:
        print("なし")


if __name__ == "__main__":
    main()
