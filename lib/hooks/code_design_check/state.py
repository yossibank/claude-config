import re

STATE_LIMIT = 12
FLAG_LIMIT = 3
OBSERVER_LIMIT = 2

OBSERVABLE = re.compile(r"^@Observable\b")
SWIFT_CLASS = re.compile(r"\bclass\s+(\w+)")
SWIFT_STORED = re.compile(
    r"^    (?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:(?:public|package|internal|fileprivate|private)(?:\((?:set)\))?\s+)*"
    r"var\s+\w+\s*(?::\s*(?P<type>[^={]+?))?\s*(?P<value>=[^{]*)?(?P<open>\{)?\s*$"
)
SWIFT_OBSERVER = re.compile(r"^\s*(?:didSet|willSet)\b")
SWIFT_NOW = re.compile(r":\s*Date\s*=\s*(?:Date\(\)|Date\.now|\.now)(?=\s*[,)]|\s*$)")
KOTLIN_STATE = re.compile(r"^    (?:(?:public|internal|private|override)\s+)*var\s+\w+.*\bby\s+mutable\w*StateOf\b")
KOTLIN_NOW = re.compile(r":\s*(?:Instant|LocalDate|LocalDateTime)\s*=\s*(?:Instant|LocalDate|LocalDateTime)\.now\(\)")
KOTLIN_CLASS = re.compile(r"^(?:(?:public|internal|private|abstract|open|data|sealed)\s+)*class\s+(\w+)")


def next_code(code, index):
    for line in code[index + 1 :]:
        if line.strip():
            return line
    return ""


def observable_classes(code):
    index = 0
    while index < len(code):
        if not OBSERVABLE.match(code[index]):
            index += 1
            continue
        start = next((at for at in range(index, len(code)) if SWIFT_CLASS.search(code[at])), None)
        if start is None:
            return
        end = next((at for at in range(start + 1, len(code)) if code[at].startswith("}")), len(code))
        yield start, end, SWIFT_CLASS.search(code[start]).group(1)
        index = end + 1


def stored_properties(code, start, end):
    for index in range(start + 1, end):
        found = SWIFT_STORED.match(code[index])
        if not found:
            continue
        observed = bool(SWIFT_OBSERVER.match(next_code(code, index)))
        if found.group("open") and not observed:
            continue
        kind = (found.group("type") or "").strip()
        value = (found.group("value") or "").lstrip("=").strip()
        yield index, kind == "Bool" or value in {"false", "true"}


def check_swift_state(code):
    for start, end, name in observable_classes(code):
        stored = list(stored_properties(code, start, end))
        flags = [index for index, is_flag in stored if is_flag]
        observers = [index for index in range(start + 1, end) if SWIFT_OBSERVER.match(code[index])]
        if len(stored) > STATE_LIMIT:
            line = stored[STATE_LIMIT][0] + 1
            yield line, f"{name} の保存プロパティの var は {STATE_LIMIT} 個までにする（今は {len(stored)} 個）。一緒に動く値を struct か enum にまとめる"
        if len(flags) > FLAG_LIMIT:
            line = flags[FLAG_LIMIT] + 1
            yield line, f"{name} の Bool の保存プロパティは {FLAG_LIMIT} 個までにする（今は {len(flags)} 個）。両立しない状態は enum にまとめる"
        if len(observers) > OBSERVER_LIMIT:
            line = observers[OBSERVER_LIMIT] + 1
            yield line, f"{name} の didSet と willSet は {OBSERVER_LIMIT} 個までにする（今は {len(observers)} 個）。派生する値は計算で出すか、入力を 1 つの型にまとめる"


def check_kotlin_state(code):
    name = next((found.group(1) for line in code if (found := KOTLIN_CLASS.match(line))), "クラス")
    states = [index for index, line in enumerate(code) if KOTLIN_STATE.match(line)]
    if len(states) > STATE_LIMIT:
        line = states[STATE_LIMIT] + 1
        yield line, f"{name} の mutableStateOf の var は {STATE_LIMIT} 個までにする（今は {len(states)} 個）。一緒に動く値を data class か sealed interface にまとめる"


def check_now(code, pattern):
    for index, line in enumerate(code):
        if pattern.search(line):
            yield index + 1, "今の時刻を引数やプロパティの既定値にしない。呼ぶ側から引数で渡す"
