import re

STATE_LIMIT = 12
FLAG_LIMIT = 3
OBSERVER_LIMIT = 2

OBSERVABLE = re.compile(r"^(\s*)@Observable\b")
SWIFT_CLASS = re.compile(r"\bclass\s+(\w+)")
SWIFT_STORED = (
    r"(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:(?:public|package|internal|fileprivate|private)(?:\((?:set)\))?\s+)*"
    r"var\s+\w+\s*(?::\s*(?P<type>[^={]+?))?\s*(?P<value>=[^{]*)?(?P<open>\{)?\s*$"
)
SWIFT_ATTRIBUTES = r"(?:@\w+(?:\([^)]*\))?\s+)*"
SWIFT_ACCESS = r"(?:(?:public|package|internal|fileprivate|private)(?:\(set\))?\s+)*"
SWIFT_GROUP = r"(?:(?:public|package|internal|fileprivate|private)\s+)?let\s+(?:state|input|output)\b"
SWIFT_PART_TYPE = r"(?:\w+\.)*(?:State|Input|Output)\b"
SWIFT_LOOSE_GROUP = SWIFT_ATTRIBUTES + SWIFT_ACCESS + r"var\s+(?P<name>state|input|output)\s*(?::\s*" + SWIFT_PART_TYPE + r"|=\s*" + SWIFT_PART_TYPE + r"\()"
SWIFT_OUTPUT = re.compile(
    r"^(\s*)(?:(?:public|package|internal|fileprivate|private)\s+)?"
    r"(?:(?:final\s+)?class\s+Output\b|extension\s+[\w.]+\.Output\b)"
)
SWIFT_IMPURE = re.compile(r"\b(?:await|async|AppDatabase|dependencies)\b")
SWIFT_DEPENDENCIES = re.compile(r"\bdependencies\.")
SWIFT_MADE_NOW = re.compile(r"\bDate\(\)|\bDate\.now\b")
OUTPUT_NOW = "Output で今の時刻を作らない。日付は state の今日を使い、時刻はモデルの関数から引数で受け取る"
SWIFT_INPUT_WRITE = re.compile(
    r"(?<!\bself)(?<!\bself\?)(?<!\bself!)\.input\.\w+(?:\.\w+|\[[^\]]*\])*"
    r"\s*(?:[-+*/]?=(?!=)|\.(?:append|insert|remove\w*|toggle)\()"
    r"|\bBindable\([\w.]*\.input\)|\$\w+\.input\."
)
SWIFT_DEPENDENCIES_READ = re.compile(r"(?<!\\)(?<!\bSelf)(?<!\bself)(?<!\bself\?)(?<!\bself!)\.dependencies\b")
OUTPUT_PASSAGE = re.compile(r"\.output\.(?:state|input)\b")
PARTS = {"State", "Input"}
SWIFT_OBSERVER = re.compile(r"^\s*(?:didSet|willSet)\b")
SWIFT_NOW = re.compile(r":\s*Date\s*=\s*(?:Date\(\)|Date\.now|\.now)(?=\s*[,)]|\s*$)")
KOTLIN_STATE = re.compile(r"^    (?:(?:public|internal|private|override)\s+)*var\s+\w+.*\bby\s+mutable\w*StateOf\b")
KOTLIN_NOW = re.compile(r":\s*(?:Instant|LocalDate|LocalDateTime)\s*=\s*(?:Instant|LocalDate|LocalDateTime)\.now\(\)")
KOTLIN_GROUP = re.compile(r"^    (?:(?:public|internal|private)\s+)?(?P<word>va[lr])\s+(?P<name>state|input|output)\s*(?::\s*[\w.<>]+\s*)?=\s*(?:State|Input|Output)\(")
KOTLIN_PART = re.compile(r"^    (?:(?:public|internal|private)\s+)?class\s+(State|Input|Output)\b")
KOTLIN_PART_STATE = re.compile(r"^        (?:(?:public|internal|private|override)\s+)*var\s+\w+\s*(?::\s*(?P<type>[^=]+?))?\s+by\s+mutable\w*StateOf\((?P<value>[^)]*)\)")
KOTLIN_OUTPUT_EXTENSION = re.compile(r"^(?:(?:public|internal|private)\s+)?(?:suspend\s+)?(?:val|var|fun)\s+(?:<[^>]*>\s*)?\w+\.Output\.")
KOTLIN_TOP = re.compile(r"^[^\s})]")
KOTLIN_IMPURE = re.compile(r"\b(?:suspend|AppDatabase|dependencies|launch|collect\w*)\b")
KOTLIN_DEPENDENCIES = re.compile(r"\bdependencies\.")
KOTLIN_MADE_NOW = re.compile(
    r"\b(?:Instant|LocalDate|LocalDateTime|LocalTime|ZonedDateTime|OffsetDateTime|Clock\.System)\.now\(\)|\bSystem\.currentTimeMillis\(\)"
)
KOTLIN_INPUT_WRITE = re.compile(r"\.input\.[\w.]+\s*(?:[-+*/]?=(?!=)|\.(?:(?:add|remove|put)\w*|clear)\()")
KOTLIN_SELF = re.compile(r"\bthis(?:@\w+)?$")
KOTLIN_CLASS = re.compile(r"^(?:(?:public|internal|private|abstract|open|data|sealed)\s+)*class\s+(\w+)")


def next_code(code, index):
    for line in code[index + 1 :]:
        if line.strip():
            return line
    return ""


def block_end(code, start, indent):
    return next((at for at in range(start + 1, len(code)) if code[at].startswith(indent + "}")), len(code))


def observable_classes(code):
    for index, line in enumerate(code):
        found = OBSERVABLE.match(line)
        if not found:
            continue
        start = next((at for at in range(index, len(code)) if SWIFT_CLASS.search(code[at])), None)
        if start is None:
            return
        indent = found.group(1)
        yield start, block_end(code, start, indent), SWIFT_CLASS.search(code[start]).group(1), indent


def stored_properties(code, start, end, indent):
    pattern = re.compile("^" + indent + "    " + SWIFT_STORED)
    for index in range(start + 1, end):
        found = pattern.match(code[index])
        if not found:
            continue
        observed = bool(SWIFT_OBSERVER.match(next_code(code, index)))
        if found.group("open") and not observed:
            continue
        kind = (found.group("type") or "").strip()
        value = (found.group("value") or "").lstrip("=").strip()
        yield index, kind == "Bool" or value in {"false", "true"}


def loose_groups(code, start, end, indent):
    pattern = re.compile("^" + indent + "    " + SWIFT_LOOSE_GROUP)
    return [(index, found.group("name")) for index in range(start + 1, end) if (found := pattern.match(code[index]))]


def is_grouped(code, start, end, indent):
    pattern = re.compile("^" + indent + "    " + SWIFT_GROUP)
    return any(pattern.match(code[index]) for index in range(start + 1, end)) or len(loose_groups(code, start, end, indent)) > 1


def check_swift_state(code):
    for start, end, name, indent in observable_classes(code):
        stored = list(stored_properties(code, start, end, indent))
        flags = [index for index, is_flag in stored if is_flag]
        observers = [index for index in range(start + 1, end) if SWIFT_OBSERVER.match(code[index])]
        if is_grouped(code, start, end, indent):
            loose = loose_groups(code, start, end, indent)
            stored = [found for found in stored if found[0] not in dict(loose)]
            for index, part in loose:
                yield index + 1, f"{name} のまとまりは let で持つ: {part}。入れ替えずに、中の値を書き換える"
            if stored:
                yield stored[0][0] + 1, f"{name} は 4 つのまとまりのモデルなので、保存プロパティの var を直下に置かない（今は {len(stored)} 個）。state か input に移す"
            if observers:
                yield observers[0] + 1, f"{name} に didSet と willSet を書かない（今は {len(observers)} 個）。連動は State の関数に置き、派生する値は Output で出す"
            continue
        if indent and name in PARTS:
            if observers:
                yield observers[0] + 1, f"まとまりの {name} に didSet と willSet を書かない（今は {len(observers)} 個）。連動は State の関数に置き、派生する値は Output で出す"
            if name == "Input":
                continue
        if len(stored) > STATE_LIMIT:
            line = stored[STATE_LIMIT][0] + 1
            yield line, f"{name} の保存プロパティの var は {STATE_LIMIT} 個までにする（今は {len(stored)} 個）。一緒に動く値を struct か enum にまとめる"
        if len(flags) > FLAG_LIMIT:
            line = flags[FLAG_LIMIT] + 1
            yield line, f"{name} の Bool の保存プロパティは {FLAG_LIMIT} 個までにする（今は {len(flags)} 個）。両立しない状態は enum にまとめる"
        if len(observers) > OBSERVER_LIMIT:
            line = observers[OBSERVER_LIMIT] + 1
            yield line, f"{name} の didSet と willSet は {OBSERVER_LIMIT} 個までにする（今は {len(observers)} 個）。派生する値は計算で出すか、入力を 1 つの型にまとめる"


def kotlin_parts(code):
    for index, line in enumerate(code):
        found = KOTLIN_PART.match(line)
        if not found:
            continue
        head = index
        if line.rstrip().endswith("("):
            head = next((at for at in range(index + 1, len(code)) if code[at].startswith("    )")), index)
        end = block_end(code, head, "    ") if code[head].rstrip().endswith("{") else head + 1
        yield index, end, found.group(1)


def kotlin_output_lines(code):
    inside = False
    for index, line in enumerate(code):
        if KOTLIN_TOP.match(line):
            inside = bool(KOTLIN_OUTPUT_EXTENSION.match(line))
        if inside:
            yield index
    for start, end, part in kotlin_parts(code):
        if part == "Output":
            yield from range(start + 1, end)


def check_kotlin_output(code):
    for index in sorted(set(kotlin_output_lines(code))):
        if KOTLIN_IMPURE.search(code[index]):
            yield index + 1, "Output は input と state から値を出すだけにする。DB・dependencies・suspend を使う処理は、モデルの関数に置く"
        if KOTLIN_MADE_NOW.search(code[index]):
            yield index + 1, OUTPUT_NOW


def check_kotlin_parts(code, name):
    for start, end, part in kotlin_parts(code):
        if part != "State":
            continue
        stored = [(index, found) for index in range(start + 1, end) if (found := KOTLIN_PART_STATE.match(code[index]))]
        flags = [index for index, found in stored if (found.group("type") or "").strip() == "Boolean" or found.group("value").strip() in {"false", "true"}]
        if len(stored) > STATE_LIMIT:
            yield stored[STATE_LIMIT][0] + 1, f"{name} の State の mutableStateOf の var は {STATE_LIMIT} 個までにする（今は {len(stored)} 個）。一緒に動く値を data class にまとめる"
        if len(flags) > FLAG_LIMIT:
            yield flags[FLAG_LIMIT] + 1, f"{name} の State の Boolean は {FLAG_LIMIT} 個までにする（今は {len(flags)} 個）。両立しない状態は sealed interface にまとめる"


def check_kotlin_state(code):
    name = next((found.group(1) for line in code if (found := KOTLIN_CLASS.match(line))), "クラス")
    states = [index for index, line in enumerate(code) if KOTLIN_STATE.match(line)]
    groups = [(index, found) for index, line in enumerate(code) if (found := KOTLIN_GROUP.match(line))]
    if groups:
        for index, found in groups:
            if found.group("word") == "var":
                yield index + 1, f"{name} のまとまりは val で持つ: {found.group('name')}。入れ替えずに、中の値を書き換える"
        if states:
            yield states[0] + 1, f"{name} は 4 つのまとまりのモデルなので、mutableStateOf の var を直下に置かない（今は {len(states)} 個）。State か Input に移す"
        yield from check_kotlin_parts(code, name)
        return
    if len(states) > STATE_LIMIT:
        line = states[STATE_LIMIT] + 1
        yield line, f"{name} の mutableStateOf の var は {STATE_LIMIT} 個までにする（今は {len(states)} 個）。一緒に動く値を data class か sealed interface にまとめる"


def check_now(code, pattern):
    for index, line in enumerate(code):
        if pattern.search(line):
            yield index + 1, "今の時刻を引数やプロパティの既定値にしない。呼ぶ側から引数で渡す"


def swift_output_lines(code):
    index = 0
    while index < len(code):
        found = SWIFT_OUTPUT.match(code[index])
        if not found:
            index += 1
            continue
        end = block_end(code, index, found.group(1))
        yield from range(index + 1, end)
        index = end + 1


def check_swift_output(code):
    for index in swift_output_lines(code):
        if SWIFT_IMPURE.search(code[index]):
            yield index + 1, "Output は input と state から値を出すだけにする。DB・dependencies・async を使う処理は、モデルの関数に置く"
        if SWIFT_MADE_NOW.search(code[index]):
            yield index + 1, OUTPUT_NOW


def check_swift_clock(code):
    if not any(SWIFT_DEPENDENCIES.search(line) for line in code):
        return
    output = set(swift_output_lines(code))
    for index, line in enumerate(code):
        if index not in output and SWIFT_MADE_NOW.search(line):
            yield index + 1, "dependencies を持つモデルで、今の時刻を作らない。dependencies の時計から受け取る"


def check_swift_input(code):
    for index, line in enumerate(code):
        if SWIFT_INPUT_WRITE.search(line):
            yield index + 1, "モデルの input に、モデルの外から書かない。モデルの関数で書き換える"


def check_kotlin_clock(code):
    if not any(KOTLIN_DEPENDENCIES.search(line) for line in code):
        return
    output = set(kotlin_output_lines(code))
    for index, line in enumerate(code):
        if index not in output and KOTLIN_MADE_NOW.search(line):
            yield index + 1, "dependencies を持つモデルで、今の時刻を作らない。dependencies の時計から受け取る"


def check_kotlin_input(code):
    for index, line in enumerate(code):
        if any(not KOTLIN_SELF.search(line[: found.start()]) for found in KOTLIN_INPUT_WRITE.finditer(line)):
            yield index + 1, "モデルの input に、モデルの外から書かない。モデルの関数で書き換える"


def check_swift_dependencies(code):
    for index, line in enumerate(code):
        if SWIFT_DEPENDENCIES_READ.search(line):
            yield index + 1, "モデルの dependencies を、モデルの外から読まない。子のモデルや画面に渡す物は、モデルの関数で作る"


def check_passage(code):
    for index, line in enumerate(code):
        if OUTPUT_PASSAGE.search(line):
            yield index + 1, "output 越しに state と input を読まない。model.state・model.input から読む"
