import re

QUOTE = re.compile(r"^\s*(>\s?)*")
FENCE = re.compile(r"^(`{3,}|~{3,})(.*)$")
FIELD = re.compile(r"^([a-z-]+):\s*(.*)$")
NESTED_FIELD = re.compile(r"^\s+([A-Za-z_-]+):\s*(.*)$")
ITEM = re.compile(r'^\s*-\s*"?([^"]+)"?\s*$')


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


def front_matter(lines):
    end = front_matter_end(lines)
    if end is None:
        return None
    fields = {}
    key = None
    for line in lines[1:end]:
        top = FIELD.match(line)
        if top:
            key = top.group(1)
            fields[key] = top.group(2).strip().strip('"')
            continue
        if key is None or not line.strip():
            continue
        item = ITEM.match(line)
        nested = NESTED_FIELD.match(line)
        if item and (fields[key] == "" or isinstance(fields[key], list)):
            fields[key] = [*fields[key], item.group(1)]
        elif nested and fields[key] == "":
            fields[nested.group(1)] = nested.group(2).strip().strip('"')
        elif isinstance(fields[key], str):
            fields[key] += "\n" + line.strip()
    return fields


def table_under(lines, heading, first_column):
    if heading not in lines:
        return []
    tables = [[]]
    for line in lines[lines.index(heading) + 1 :]:
        if line.startswith("#"):
            break
        if line.startswith("|"):
            tables[-1].append([cell.strip().strip("`") for cell in line.strip().strip("|").split("|")])
        elif tables[-1]:
            tables.append([])
    return next((table[2:] for table in tables if table and table[0][0] == first_column), [])
