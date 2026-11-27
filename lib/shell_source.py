import re

HEREDOC = re.compile(r"<<(-?)[ \t]*(?:'([^'\n]*)'|\"([^\"\n]*)\"|([A-Za-z0-9_.-]+))")
COMMENT_AFTER = set(" \t;&|(")


def scan(line, quote):
    found = []
    index = 0
    while index < len(line):
        char = line[index]
        if quote == "'":
            quote = None if char == "'" else quote
        elif char == "\\":
            index += 2
            continue
        elif quote == '"':
            quote = None if char == '"' else quote
        elif char in "'\"":
            quote = char
        elif char == "#" and (index == 0 or line[index - 1] in COMMENT_AFTER):
            return found, quote, index
        elif line.startswith("<<<", index):
            index += 3
            continue
        elif match := HEREDOC.match(line, index):
            strip, single, double, bare = match.groups()
            quoted = single is not None or double is not None
            found.append((strip == "-", next(word for word in (single, double, bare) if word is not None), quoted))
            index = match.end()
            continue
        index += 1
    return found, quote, None


def heredocs(line, quote):
    found, quote, _ = scan(line, quote)
    return found, quote


def is_heredoc_end(line, heredoc):
    strip, end, _ = heredoc
    return (line.lstrip("\t") if strip else line) == end


def comments(text):
    ends = []
    quote = None
    for number, line in enumerate(text.split("\n"), 1):
        if ends:
            if is_heredoc_end(line, ends[0]):
                ends.pop(0)
            continue
        ends, quote, start = scan(line, quote)
        if start is not None:
            yield number, line[start:]
