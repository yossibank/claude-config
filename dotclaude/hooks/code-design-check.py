import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "lib"))

import kotlin_source  # noqa: E402
import swift_source  # noqa: E402
from hooks.code_design_check import baseline  # noqa: E402
from hooks.code_design_check.clones import Clones  # noqa: E402
from hooks.code_design_check.files import (  # noqa: E402
    check_folder,
    check_kotlin_types,
    check_length,
    check_parts,
    check_swift_name,
    check_swift_types,
    is_test,
    is_tooling,
    root_of,
)
from hooks.code_design_check.state import (  # noqa: E402
    KOTLIN_NOW,
    SWIFT_NOW,
    check_kotlin_state,
    check_now,
    check_swift_clock,
    check_swift_output,
    check_swift_state,
)
from hook_io import run_gate, run_hook, target_paths  # noqa: E402

HEADER = "設計の決まり（rules/code-design.md）に合わない箇所がある。直す。"
VERIFY_PREFIX = "NG "
WRITE_BASELINE = "--write-baseline"


def from_verify():
    return len(sys.argv) > 1


def read(path, mask):
    with open(path, encoding="utf-8") as file:
        text = file.read()
    return text.split("\n"), mask(text)


def swift_checker(paths):
    clones = Clones(paths, ".swift", swift_source.mask)
    folders = set()

    def check(path):
        lines, code = read(path, swift_source.mask)
        findings = [*check_length(lines)]
        if not is_test(path):
            findings += [
                *check_swift_name(path, code),
                *check_swift_types(path, code),
                *check_folder(path, ".swift", folders),
                *check_parts(path, code, clones.root_of(os.path.realpath(path))),
                *check_swift_state(code),
                *check_swift_output(code),
                *check_swift_clock(code),
                *check_now(code, SWIFT_NOW),
                *clones.check(path),
            ]
        return sorted(findings)

    return check


def kotlin_checker(paths):
    clones = Clones(paths, ".kt", kotlin_source.mask)

    def check(path):
        lines, code = read(path, kotlin_source.mask)
        findings = [*check_length(lines)]
        if not is_test(path):
            findings += [
                *check_kotlin_types(path, code),
                *check_kotlin_state(code),
                *check_now(code, KOTLIN_NOW),
                *clones.check(path),
            ]
        return sorted(findings)

    return check


def findings_of(paths):
    swift = [path for path in paths if path.endswith(".swift")]
    kotlin = [path for path in paths if path.endswith(".kt")]
    checks = {".swift": swift_checker(swift), ".kt": kotlin_checker(kotlin)}
    return [(path, line, message) for path in [*swift, *kotlin] for line, message in checks[os.path.splitext(path)[1]](path)]


def by_root(findings):
    roots = {}
    for path, line, message in findings:
        root = root_of(os.path.dirname(os.path.realpath(path)))
        if root:
            roots.setdefault(root, set()).add(baseline.key(root, os.path.realpath(path), message))
    return roots


def write_baseline(paths, findings):
    roots = {root: set() for root in filter(None, (root_of(os.path.dirname(os.path.realpath(path))) for path in paths))}
    roots.update(by_root(findings))
    for root, keys in roots.items():
        baseline.write(root, keys)
        print(f"OK 基準線を書いた: {os.path.join(root, baseline.NAME)}（{len(keys)} 件）")


def unknown_of(paths, findings, with_stale):
    roots = {root_of(os.path.dirname(os.path.realpath(path))) for path in paths}
    known = {root: baseline.read(root) for root in roots if root}
    report = []
    seen = set()
    for path, line, message in findings:
        real = os.path.realpath(path)
        root = root_of(os.path.dirname(real))
        entries = known.get(root, set())
        entry = baseline.key(root, real, message) if root else ""
        if entry in entries:
            seen.add((root, entry))
        else:
            report.append(f"{path}:{line}: {message}")
    if not with_stale:
        return report
    checked = {os.path.realpath(path) for path in paths}
    for root, entries in known.items():
        for entry in sorted(entries):
            if (root, entry) not in seen and os.path.realpath(baseline.path_of(root, entry)) in checked:
                report.append(f"{os.path.join(root, baseline.NAME)}: 基準線にある外れが、もう無い。行を消す: {entry}")
    return report


def main():
    paths = [path for path in target_paths("") if not is_tooling(path)]
    findings = findings_of(paths)
    if WRITE_BASELINE in sys.argv[1:]:
        write_baseline(paths, findings)
        return
    prefix = VERIFY_PREFIX if from_verify() else ""
    report = unknown_of(paths, findings, from_verify())
    if report:
        print(HEADER + "\n" + "\n".join(prefix + line for line in report), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    if from_verify():
        run_gate("code-design-check", main, VERIFY_PREFIX)
    else:
        run_hook("code-design-check", main)
