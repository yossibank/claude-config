import os
import re
from collections import Counter

NAME = os.path.join(".claude", "code-design-baseline.txt")
LINE_REF = re.compile(r":\d+")


def key(root, path, message):
    return f"{os.path.relpath(path, root)}: {LINE_REF.sub('', message)}"


def read(root):
    try:
        with open(os.path.join(root, NAME), encoding="utf-8") as file:
            return Counter(line.strip() for line in file if line.strip())
    except OSError:
        return Counter()


def write(root, keys):
    path = os.path.join(root, NAME)
    if not keys:
        if os.path.exists(path):
            os.remove(path)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as file:
        file.write("\n".join(sorted(keys.elements())) + "\n")


def path_of(root, entry):
    return os.path.join(root, entry.split(": ", 1)[0])
