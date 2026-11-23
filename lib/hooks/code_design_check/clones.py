import hashlib
import json
import os
import re
import tempfile

from git import git, git_root
from hook_state import prepare_state, safe_name, state_folder
from hooks.code_design_check.files import SERIAL, is_test, stem

WINDOW = 20
VARIETY = 10
STALE = 60 * 60 * 24 * 14
# shape・KEYWORDS・TRIVIAL・mask を変えたら上げる。古いキャッシュは読まずに、STALE で消える
VERSION = 1
STATE = state_folder("code-design-check")

IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
SPACES = re.compile(r"\s+")
TRIVIAL = re.compile(r"^[\s{}()\[\],.;:]*$")
SKIPPED = re.compile(r"^\s*(?:import|package)\s")
KEYWORDS = frozenset(
    "actor any as async await by case catch class companion data default defer do else enum extension false fileprivate final for fun func "
    "get guard if import in init interface internal is let mutating nil nonisolated null object override private protocol public return "
    "sealed self Self set some static struct super suspend switch this throw throws true try val var when where while".split()
)


def is_source(path):
    return not is_test(path) and not SERIAL.search(stem(path))


def shape(line):
    text = SPACES.sub(" ", line.strip())
    return IDENTIFIER.sub(lambda found: found.group(0) if found.group(0) in KEYWORDS else "_", text)


def rows_of(code):
    rows = []
    for number, line in enumerate(code, 1):
        if TRIVIAL.match(line) or SKIPPED.match(line):
            continue
        digest = hashlib.blake2b(shape(line).encode(), digest_size=6).hexdigest()
        rows.append([number, digest])
    return rows


def windows(rows):
    for index in range(len(rows) - WINDOW + 1):
        part = [digest for _, digest in rows[index : index + WINDOW]]
        if len(set(part)) >= VARIETY:
            yield index, "".join(part)


def tracked(root, suffix):
    result = git(root, "ls-files", "-z", "--", f"*{suffix}")
    names = result.stdout.split("\0") if result and result.returncode == 0 else []
    return [os.path.join(root, name) for name in names if name]


def cache_path(root, suffix):
    return os.path.join(STATE, safe_name(f"{root}{suffix}-v{VERSION}") + ".json")


def load_cache(path):
    try:
        with open(path, encoding="utf-8") as file:
            data = json.load(file)
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def save_cache(path, cache):
    try:
        handle, temporary = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
        with os.fdopen(handle, "w", encoding="utf-8") as file:
            json.dump(cache, file)
        os.replace(temporary, path)
    except OSError:
        pass


def read_rows(path, cache, mask):
    try:
        stat = os.stat(path)
        stamp = [stat.st_mtime_ns, stat.st_size]
        entry = cache.get(path)
        if entry and entry[0] == stamp:
            return entry[1]
        with open(path, encoding="utf-8") as file:
            rows = rows_of(mask(file.read()))
    except (OSError, UnicodeDecodeError):
        return []
    cache[path] = [stamp, rows]
    return rows


class Clones:
    def __init__(self, targets, suffix, mask):
        self.targets = {os.path.realpath(path) for path in targets}
        self.suffix = suffix
        self.mask = mask
        self.roots = {}
        self.folders = {}

    def index(self, root):
        if root in self.roots:
            return self.roots[root]
        prepare_state(STATE, STALE)
        store = cache_path(root, self.suffix)
        cache = load_cache(store)
        paths = sorted({*tracked(root, self.suffix), *(path for path in self.targets if path.startswith(root + os.sep))})
        paths = [path for path in paths if is_source(path) and os.path.isfile(path)]
        files = {path: read_rows(path, cache, self.mask) for path in paths}
        save_cache(store, {path: cache[path] for path in paths if path in cache})
        places = {}
        for path, rows in files.items():
            for index, key in windows(rows):
                places.setdefault(key, []).append((path, index))
        self.roots[root] = (files, places)
        return self.roots[root]

    def root_of(self, path):
        folder = os.path.dirname(path)
        if folder not in self.folders:
            known = next((root for root in self.roots if path.startswith(root + os.sep)), None)
            self.folders[folder] = known or git_root(path)
        return self.folders[folder]

    def check(self, path):
        if not is_source(path):
            return
        path = os.path.realpath(path)
        root = self.root_of(path)
        if not root:
            return
        files, places = self.index(root)
        rows = files.get(path, [])
        reported = set()
        for index, key in windows(rows):
            for other, at in places.get(key, []):
                if other == path or other in reported:
                    continue
                reported.add(other)
                if other in self.targets and other < path:
                    continue
                where = f"{os.path.relpath(other, root)}:{files[other][at][0]}"
                yield rows[index][0], f"ここから {WINDOW} 行以上が、{where} と同じ形になっている。共通の部品・関数・型に括る"
