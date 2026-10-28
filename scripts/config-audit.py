import ast
import fnmatch
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILL_DIR = "${CLAUDE_SKILL_DIR}"
SKILL_PATH = re.compile(r"((?:python3 -I |python3 |bash )?)\$\{CLAUDE_SKILL_DIR\}/((?:\.\./[a-z-]+/)?(?:scripts|templates)/[A-Za-z0-9_.-]+)")
ALIAS = re.compile(r"`(<[A-Z]+>)` は `\$\{CLAUDE_SKILL_DIR\}/([a-z/]+)`")
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
    return re.findall(r"Bash\(([^)]*)\)", fields.get("allowed-tools", ""))


def expand_aliases(text):
    for alias, target in ALIAS.findall(text):
        text = text.replace(f"{alias}/", f"{SKILL_DIR}/{target}/")
    return text


def covered(prefix, reference, patterns):
    command = f"{prefix}{SKILL_DIR}/{reference} x"
    return any(fnmatch.fnmatchcase(command, pattern) for pattern in patterns)


def skill_names():
    return sorted(os.path.basename(os.path.dirname(path)) for path in tracked("skills/*/SKILL.md"))


def check_skills():
    for skill_dir in skill_names():
        base = os.path.join(ROOT, "skills", skill_dir)
        skill = os.path.join(base, "SKILL.md")
        fields = front_matter(skill) or {}
        if fields.get("name") != skill_dir:
            ng(skill, 2, f"name がフォルダ名 {skill_dir} と違う: {fields.get('name')}")
        if not fields.get("description", "").endswith("。"):
            ng(skill, 3, "description を「。」で終える")
        patterns = allowed_patterns(fields)
        for number, line in enumerate(expand_aliases(read(skill)).split("\n"), 1):
            if line.startswith("allowed-tools:"):
                continue
            for prefix, reference in SKILL_PATH.findall(line):
                target = os.path.normpath(os.path.join(base, reference))
                if not os.path.exists(target):
                    ng(skill, number, f"参照先が無い: {reference}")
                    continue
                if "scripts/" not in reference:
                    continue
                allowed = covered(prefix, reference, patterns)
                if f"{skill_dir}/{reference}" in ASK_EVERY_TIME:
                    if allowed:
                        ng(skill, number, f"外に出す操作が allowed-tools で自動で許可されている: {reference}")
                elif not allowed:
                    ng(skill, number, f"allowed-tools で許可していない: {prefix}{reference}")
        check_unused(skill_dir)


def check_unused(skill_dir):
    scripts = tracked(f"skills/{skill_dir}/scripts/*")
    own_skill = expand_aliases(read(os.path.join(ROOT, "skills", skill_dir, "SKILL.md")))
    other_skills = [expand_aliases(read(path)) for path in tracked("skills/*/SKILL.md")]
    for path in scripts:
        name = os.path.basename(path)
        in_own_skill = f"{SKILL_DIR}/scripts/{name}" in own_skill
        in_other_skill = any(f"{SKILL_DIR}/../{skill_dir}/scripts/{name}" in text for text in other_skills)
        in_sibling = any(
            re.search(rf"[/\"'\s]{re.escape(name)}\b", read(sibling)) for sibling in scripts if sibling != path
        )
        if not (in_own_skill or in_other_skill or in_sibling):
            ng(path, 1, "どこからも使われていない")


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
    links = {target.rstrip("/") for target in LINK.findall(read(readme))}
    entries = [f"skills/{name}/SKILL.md" for name in skill_names()]
    entries += [os.path.relpath(path, ROOT) for path in tracked("agents/*.md", "rules/*.md", "hooks/*.py", "scripts/*")]
    for entry in entries:
        if entry not in links:
            ng(readme, 1, f"README の表に載っていない: {entry}")


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
    hook = os.path.join(ROOT, "hooks", "post-edit-check-docs.py")
    result = subprocess.run([sys.executable, "-I", hook, *tracked("*.md")], capture_output=True, text=True)
    lines = [line for line in result.stderr.splitlines() if line.startswith("/")]
    for line in lines:
        path, number, message = line.split(":", 2)
        ng(path, number, message.strip())
    if result.returncode not in (0, 2) or (result.returncode == 2 and not lines):
        ng(hook, 1, f"文書の検査が落ちた: {result.stderr.strip()[-200:]}")


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
