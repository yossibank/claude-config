import re

QUOTE = re.compile(r"^\s*(>\s?)*")
FENCE = re.compile(r"^(`{3,}|~{3,})(.*)$")


def fence_marks(lines):
    marks = []
    opener = None
    for line in lines:
        match = FENCE.match(QUOTE.sub("", line).lstrip())
        if opener is None:
            if match:
                opener = match.group(1)
                marks.append(("open", match.group(2).strip()))
            else:
                marks.append((None, ""))
        elif match and match.group(1)[0] == opener[0] and len(match.group(1)) >= len(opener) and not match.group(2).strip():
            opener = None
            marks.append(("close", ""))
        else:
            marks.append(("code", ""))
    return marks


def front_matter_end(lines):
    if not lines or lines[0] != "---":
        return None
    return next((i for i in range(1, len(lines)) if lines[i] == "---"), None)
