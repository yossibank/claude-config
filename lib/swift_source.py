def mask(text):
    """コメントと文字列の中身を空白にし、行ごとの文字数を変えずに行の一覧で返す。"""
    out = []
    stack = []
    block = 0
    i = 0
    while i < len(text):
        c = text[i]
        top = stack[-1] if stack else None
        shown = top is None
        if block:
            if text.startswith("/*", i):
                block += 1
            elif text.startswith("*/", i):
                block -= 1
                out.append("  ")
                i += 2
                continue
            out.append("\n" if c == "\n" else " ")
        elif shown or top[0] == "interp":
            if shown and text.startswith("//", i):
                end = text.find("\n", i)
                end = len(text) if end < 0 else end
                out.append(" " * (end - i))
                i = end
                continue
            if shown and text.startswith("/*", i):
                block = 1
                out.append("  ")
                i += 2
                continue
            if text.startswith('"""', i):
                stack.append(["multi"])
                out.append('"""' if shown else "   ")
                i += 3
                continue
            if c == '"':
                stack.append(["string"])
                out.append('"' if shown else " ")
            elif shown:
                out.append(c)
            else:
                if c == "(":
                    top[1] += 1
                elif c == ")":
                    top[1] -= 1
                    if top[1] == 0:
                        stack.pop()
                out.append("\n" if c == "\n" else " ")
        elif c == "\\":
            if text.startswith("\\(", i):
                stack.append(["interp", 1])
                out.append("  ")
                i += 2
                continue
            step = 2 if i + 1 < len(text) and text[i + 1] != "\n" else 1
            out.append(" " * step)
            i += step
            continue
        elif top[0] == "multi" and text.startswith('"""', i):
            stack.pop()
            out.append('"""' if not stack else "   ")
            i += 3
            continue
        elif top[0] == "string" and (c == '"' or c == "\n"):
            stack.pop()
            out.append(c if not stack or c == "\n" else " ")
        else:
            out.append("\n" if c == "\n" else " ")
        i += 1
    return "".join(out).split("\n")
