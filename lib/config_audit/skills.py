import fnmatch
import functools
import os
import re

from config_audit.files import fields_of, headings, read, skill_names, tracked
from loader import DOTCLAUDE


SKILL_DIR = "${CLAUDE_SKILL_DIR}"
SKILL_PATH = re.compile(r"((?:python3 -I |python3 |bash )?)\$\{CLAUDE_SKILL_DIR\}/((?:\.\./[a-z-]+/)?(?:scripts|templates)/[A-Za-z0-9_.-]+)")
ALIAS = re.compile(r"`(<[A-Z]+>)` は `\$\{CLAUDE_SKILL_DIR\}/([a-z/]+)`")
SKILL_REF = re.compile(r"\$\{CLAUDE_SKILL_DIR\}/([A-Za-z0-9_./-]*)(.?)")
SKILL_SECTIONS = ["起動条件", "入力", "手順", "報告", "制約"]
DESCRIPTION_LIMIT = 120
# 外に出す操作は、走らせるたびに人の許可を求めるよう allowed-tools に入れない
ASK_EVERY_TIME = {"store-release/scripts/archive-app.sh", "store-reply/scripts/send-replies.py"}


def skill_section_problems(skill):
    found = headings(skill)
    names = [name for _, name in found]
    for need in ("手順", "報告"):
        if need not in names:
            yield skill, 1, f"## {need} が無い"
    fixed = [(number, name) for number, name in found if name in SKILL_SECTIONS]
    for (_, before), (number, after) in zip(fixed, fixed[1:]):
        if SKILL_SECTIONS.index(before) >= SKILL_SECTIONS.index(after):
            yield skill, number, f"## {after} は {'・'.join(SKILL_SECTIONS)} の順に置く"
    if "手順" in names and "報告" in names:
        start, end = names.index("手順"), names.index("報告")
        for index, (number, name) in enumerate(found):
            if name not in SKILL_SECTIONS and not start < index < end:
                yield skill, number, f"## {name} は、## 手順 と ## 報告 の間に置く"


def allowed_patterns(fields):
    return re.findall(r"Bash\(([^)]*)\)", fields.get("allowed-tools", ""))


def expand_aliases(text):
    for alias, target in ALIAS.findall(text):
        text = text.replace(f"{alias}/", f"{SKILL_DIR}/{target}/")
    return text


def covered(prefix, reference, patterns):
    command = f"{prefix}{SKILL_DIR}/{reference} x"
    return any(fnmatch.fnmatchcase(command, pattern) for pattern in patterns)


@functools.cache
def expanded_skills():
    return tuple(expand_aliases(read(path)) for path in tracked("dotclaude/skills/*/SKILL.md"))


def check_skill_fields():
    for skill_dir in skill_names():
        skill = os.path.join(DOTCLAUDE, "skills", skill_dir, "SKILL.md")
        fields = fields_of(skill)
        if fields.get("name") != skill_dir:
            yield skill, 2, f"name がフォルダ名 {skill_dir} と違う: {fields.get('name')}"
        if not fields.get("description", "").endswith("。"):
            yield skill, 3, "description を「。」で終える"
        if len(fields.get("description", "")) > DESCRIPTION_LIMIT:
            yield skill, 3, f"description が {DESCRIPTION_LIMIT} 字を超えている。毎回読み込まれるので短くする"
        yield from skill_section_problems(skill)


def script_permission_problems(skill_dir, line, patterns):
    base = os.path.join(DOTCLAUDE, "skills", skill_dir)
    for prefix, reference in SKILL_PATH.findall(line):
        if "scripts/" not in reference or not os.path.exists(os.path.normpath(os.path.join(base, reference))):
            continue
        allowed = covered(prefix, reference, patterns)
        if f"{skill_dir}/{reference}" in ASK_EVERY_TIME:
            if allowed:
                yield f"外に出す操作が allowed-tools で自動で許可されている: {reference}"
        elif not allowed:
            yield f"allowed-tools で許可していない: {prefix}{reference}"


def check_skill_references():
    for skill_dir in skill_names():
        base = os.path.join(DOTCLAUDE, "skills", skill_dir)
        skill = os.path.join(base, "SKILL.md")
        patterns = allowed_patterns(fields_of(skill))
        for number, line in enumerate(expand_aliases(read(skill)).split("\n"), 1):
            if line.startswith("allowed-tools:"):
                continue
            for reference, after in SKILL_REF.findall(line):
                reference = reference.rstrip("./")
                if reference and after not in ("<", "*") and not os.path.exists(os.path.join(base, reference)):
                    yield skill, number, f"参照先が無い: {reference}"
            for message in script_permission_problems(skill_dir, line, patterns):
                yield skill, number, message


def check_skill_unused():
    for skill_dir in skill_names():
        yield from unused_scripts(skill_dir)


def unused_scripts(skill_dir):
    scripts = tracked(f"dotclaude/skills/{skill_dir}/scripts/*")
    own_skill = expand_aliases(read(os.path.join(DOTCLAUDE, "skills", skill_dir, "SKILL.md")))
    for path in scripts:
        name = os.path.basename(path)
        in_own_skill = f"{SKILL_DIR}/scripts/{name}" in own_skill
        in_other_skill = any(f"{SKILL_DIR}/../{skill_dir}/scripts/{name}" in text for text in expanded_skills())
        in_sibling = any(
            re.search(rf"[/\"'\s]{re.escape(name)}\b", read(sibling)) for sibling in scripts if sibling != path
        )
        if not (in_own_skill or in_other_skill or in_sibling):
            yield path, 1, "どこからも使われていない"


def check_skill_steps():
    for name in skill_names():
        skill = os.path.join(DOTCLAUDE, "skills", name, "SKILL.md")
        steps = re.search(r"^## 手順\n(.*?)(?=^## |\Z)", read(skill), re.M | re.S)
        if steps and not re.search(r"^1\. ", steps.group(1), re.M):
            yield skill, 1, "「手順」は番号付きの箇条書きで書く"
