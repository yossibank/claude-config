import os
import re

from config_audit.files import fields_of, headings, read, tracked
from hook_io import EDIT_TOOLS

WRITE_TOOLS = re.compile(rf"\b(?:{'|'.join(EDIT_TOOLS)})\b")


def check_agents():
    for path in tracked("dotclaude/agents/*.md"):
        fields = fields_of(path)
        name = os.path.splitext(os.path.basename(path))[0]
        if fields.get("name") != name:
            yield path, 2, f"name がファイル名 {name} と違う: {fields.get('name')}"
        if not fields.get("model"):
            yield path, 1, "model が無い"
        found = headings(path)
        if not found or found[-1][1] != "返す形":
            yield path, found[-1][0] if found else 1, "agents の最後の ## は「返す形」にする"
        body = read(path).split("\n---\n", 1)[-1]
        tools = fields.get("tools")
        if "書き換えない" in body and (tools is None or WRITE_TOOLS.search(tools)):
            yield path, 1, f"書き換えないエージェントは tools を書き、{'・'.join(EDIT_TOOLS)} を入れない"


def check_rules():
    for path in tracked("dotclaude/rules/*.md"):
        if "paths" not in fields_of(path):
            yield path, 1, "frontmatter に paths が無い"
