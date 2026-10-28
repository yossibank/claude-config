import re

QUOTE = re.compile(r"^\s*(>\s?)*")


def is_fence(line):
    return QUOTE.sub("", line).lstrip().startswith(("```", "~~~"))


def front_matter_end(lines):
    if not lines or lines[0] != "---":
        return None
    return next((i for i in range(1, len(lines)) if lines[i] == "---"), None)
