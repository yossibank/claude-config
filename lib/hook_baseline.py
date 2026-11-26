import os
import re
import sys
from collections import Counter

from code_files import root_of

LINE_REF = re.compile(r":\d+")
VERIFY_PREFIX = "NG "
WRITE_BASELINE = "--write-baseline"


def from_verify():
    return len(sys.argv) > 1


class Baseline:
    def __init__(self, name):
        self.name = os.path.join(".claude", name)

    def key(self, root, path, message):
        return f"{os.path.relpath(path, root)}: {LINE_REF.sub('', message)}"

    def read(self, root):
        try:
            with open(os.path.join(root, self.name), encoding="utf-8") as file:
                return Counter(line.strip() for line in file if line.strip())
        except OSError:
            return Counter()

    def write(self, root, keys):
        path = os.path.join(root, self.name)
        if not keys:
            if os.path.exists(path):
                os.remove(path)
            return
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as file:
            file.write("\n".join(sorted(keys.elements())) + "\n")

    def path_of(self, root, entry):
        return os.path.join(root, entry.split(": ", 1)[0])

    def by_root(self, findings):
        roots = {}
        for path, line, message in findings:
            root = root_of(os.path.dirname(os.path.realpath(path)))
            if root:
                roots.setdefault(root, Counter())[self.key(root, os.path.realpath(path), message)] += 1
        return roots

    def kept_entry(self, root, entry, checked):
        target = os.path.realpath(self.path_of(root, entry))
        return target not in checked and os.path.exists(target)

    def write_all(self, paths, findings):
        checked = {os.path.realpath(path) for path in paths}
        found = self.by_root(findings)
        for root in filter(None, {root_of(os.path.dirname(path)) for path in checked}):
            kept = Counter({entry: count for entry, count in self.read(root).items() if self.kept_entry(root, entry, checked)})
            keys = kept + found.get(root, Counter())
            self.write(root, keys)
            print(f"OK 基準線を書いた: {os.path.join(root, self.name)}（{sum(keys.values())} 件）")

    def unknown_of(self, paths, findings, with_stale):
        roots = {root_of(os.path.dirname(os.path.realpath(path))) for path in paths}
        left = {root: self.read(root) for root in roots if root}
        report = []
        for path, line, message in findings:
            real = os.path.realpath(path)
            root = root_of(os.path.dirname(real))
            entries = left.get(root, Counter())
            entry = self.key(root, real, message) if root else ""
            if entries[entry] > 0:
                entries[entry] -= 1
            else:
                report.append(f"{path}:{line}: {message}")
        if not with_stale:
            return report
        checked = {os.path.realpath(path) for path in paths}
        for root, entries in left.items():
            for entry in sorted(entry for entry, count in entries.items() if count > 0):
                target = os.path.realpath(self.path_of(root, entry))
                if target in checked or not os.path.exists(target):
                    report.append(f"{os.path.join(root, self.name)}: 基準線にある外れが、もう無い。行を消す: {entry}")
        return report

    def report(self, header, paths, findings):
        if WRITE_BASELINE in sys.argv[1:]:
            self.write_all(paths, findings)
            return
        prefix = VERIFY_PREFIX if from_verify() else ""
        report = self.unknown_of(paths, findings, from_verify())
        if report:
            print(header + "\n" + "\n".join(prefix + line for line in report), file=sys.stderr)
            sys.exit(2)
