import ast
import fnmatch
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILL_PATH = re.compile(r"\$\{CLAUDE_SKILL_DIR\}/((?:\.\./[a-z-]+/)?(?:scripts|templates)/[A-Za-z0-9_.-]+)")
LINK = re.compile(r"\]\(([^)#\s]+)(?:#[^)]*)?\)")
VAR_BEFORE_WIDE = re.compile(r"\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7F]")
HOOK_FILE = re.compile(r"claude-config/(hooks/[A-Za-z0-9_.-]+\.py)")
# 外に出す操作は、走らせるたびに人の許可を求めるよう allowed-tools に入れない
ASK_EVERY_TIME = {"store-release/scripts/archive.sh"}

problems = []


def ng(path, line, message):
    problems.append(f"NG {os.path.relpath(path, ROOT)}:{line} {message}")


def tracked(*patterns):
    out = subprocess.run(["git", "-C", ROOT, "ls-files", *patterns], capture_output=True, text=True, check=True).stdout
    return [os.path.join(ROOT, path) for path in out.splitlines()]


def read(path):
    return open(path, encoding="utf-8").read()


def front_matter(path):
    lines = read(path).split("\n")
    if not lines or lines[0] != "---":
        return None
    end = next((i for i in range(1, len(lines)) if lines[i] == "---"), None)
    if end is None:
        return None
    fields = {}
    key = None
    for line in lines[1:end]:
        match = re.match(r"^([a-z-]+):\s*(.*)$", line)
        if match:
            key = match.group(1)
            fields[key] = match.group(2).strip().strip('"')
        elif key and line.strip():
            fields[key] += "\n" + line.strip()
    return fields


def allowed_patterns(fields):
    tools = fields.get("allowed-tools", "")
    return [match.group(1) for match in re.finditer(r"Bash\(([^)]*)\)", tools)]


def check_skills():
    for skill_dir in sorted(os.listdir(os.path.join(ROOT, "skills"))):
        base = os.path.join(ROOT, "skills", skill_dir)
        skill = os.path.join(base, "SKILL.md")
        if not os.path.isfile(skill):
            ng(base, 1, "SKILL.md が無い")
            continue
        fields = front_matter(skill) or {}
        if fields.get("name") != skill_dir:
            ng(skill, 2, f"name がフォルダ名 {skill_dir} と違う: {fields.get('name')}")
        if not fields.get("description", "").endswith("。"):
            ng(skill, 3, "description を「。」で終える")
        text = read(skill)
        patterns = allowed_patterns(fields)
        for number, line in enumerate(text.split("\n"), 1):
            for reference in SKILL_PATH.findall(line):
                target = os.path.normpath(os.path.join(base, reference))
                if not os.path.exists(target):
                    ng(skill, number, f"参照先が無い: {reference}")
                elif (
                    "scripts/" in reference
                    and f"{skill_dir}/{reference}" not in ASK_EVERY_TIME
                    and not covered(reference, patterns)
                ):
                    ng(skill, number, f"allowed-tools で許可していない: {reference}")
        scripts = os.path.join(base, "scripts")
        if os.path.isdir(scripts):
            check_unused(skill_dir, scripts)


def covered(reference, patterns):
    command = f"${{CLAUDE_SKILL_DIR}}/{reference}"
    candidates = [f"python3 -I {command} x"] if reference.endswith(".py") else [f"{command} x", f"bash {command} x"]
    return any(fnmatch.fnmatchcase(candidate, pattern) for pattern in patterns for candidate in candidates)


def check_unused(skill_dir, scripts):
    texts = "\n".join(read(path) for path in tracked("skills") if path.endswith((".md", ".sh", ".py")))
    for name in sorted(os.listdir(scripts)):
        if name not in texts.replace(f"skills/{skill_dir}/scripts/{name}", ""):
            ng(os.path.join(scripts, name), 1, "どこからも使われていない")


def check_agents():
    for path in tracked("agents/*.md"):
        fields = front_matter(path) or {}
        name = os.path.splitext(os.path.basename(path))[0]
        if fields.get("name") != name:
            ng(path, 2, f"name がファイル名 {name} と違う: {fields.get('name')}")
        if not fields.get("model"):
            ng(path, 1, "model が無い")


def check_rules():
    for path in tracked("rules/*.md"):
        if "paths" not in (front_matter(path) or {}):
            ng(path, 1, "frontmatter に paths が無い")


def check_readme():
    readme = os.path.join(ROOT, "README.md")
    text = read(readme)
    entries = [os.path.join("skills", name) for name in os.listdir(os.path.join(ROOT, "skills"))]
    entries += [os.path.relpath(path, ROOT) for path in tracked("agents/*.md", "rules/*.md", "hooks/*.py", "scripts/*")]
    for entry in sorted(entries):
        if entry not in text:
            ng(readme, 1, f"README に載っていない: {entry}")


def check_links():
    for path in tracked("*.md"):
        if "/templates/" in path:
            continue
        for number, line in enumerate(read(path).split("\n"), 1):
            for target in LINK.findall(line):
                if re.match(r"[a-z]+:", target) or target.startswith("<"):
                    continue
                if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(path), target))):
                    ng(path, number, f"リンク先が無い: {target}")


def check_settings():
    path = os.path.join(ROOT, "settings", "settings.json")
    for group in json.load(open(path, encoding="utf-8")).get("hooks", {}).values():
        for entry in group:
            for hook in entry.get("hooks", []):
                for target in HOOK_FILE.findall(hook.get("command", "")):
                    if not os.path.isfile(os.path.join(ROOT, target)):
                        ng(path, 1, f"フックのファイルが無い: {target}")


def check_scripts():
    for path in tracked("*.sh"):
        result = subprocess.run(["bash", "-n", path], capture_output=True, text=True)
        if result.returncode:
            ng(path, 1, f"bash -n が通らない: {result.stderr.strip().splitlines()[-1]}")
        for number, line in enumerate(read(path).split("\n"), 1):
            if VAR_BEFORE_WIDE.search(line):
                ng(path, number, "変数の直後に全角の文字がある。${名前} で囲む")
    for path in tracked("*.py"):
        try:
            ast.parse(read(path))
        except SyntaxError as error:
            ng(path, error.lineno or 1, f"Python の構文が通らない: {error.msg}")


def check_docs():
    paths = [path for path in tracked("*.md") if "/templates/" not in path]
    result = subprocess.run(
        [sys.executable, "-I", os.path.join(ROOT, "hooks", "post-edit-check-docs.py"), *paths],
        capture_output=True,
        text=True,
    )
    for line in result.stderr.splitlines():
        if line.startswith("/"):
            path, number, message = line.split(":", 2)
            ng(path, number, message.strip())


def main():
    check_skills()
    check_agents()
    check_rules()
    check_readme()
    check_links()
    check_settings()
    check_scripts()
    check_docs()
    if problems:
        print("\n".join(problems))
        print(f"NG config-audit: {len(problems)} 件")
        sys.exit(1)
    print("OK config-audit")


if __name__ == "__main__":
    main()
