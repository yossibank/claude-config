import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "lib"))

import kotlin_source  # noqa: E402
import swift_source  # noqa: E402
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
)
from hooks.code_design_check.state import (  # noqa: E402
    KOTLIN_NOW,
    SWIFT_NOW,
    check_kotlin_state,
    check_now,
    check_swift_state,
)
from hook_io import block_on_findings, run_gate, run_hook, target_paths  # noqa: E402

HEADER = "設計の決まり（rules/code-design.md）に合わない箇所がある。直す。"
VERIFY_PREFIX = "NG "


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


def main():
    paths = [path for path in target_paths("") if not is_tooling(path)]
    swift = [path for path in paths if path.endswith(".swift")]
    kotlin = [path for path in paths if path.endswith(".kt")]
    checks = {".swift": swift_checker(swift), ".kt": kotlin_checker(kotlin)}
    block_on_findings(HEADER, [*swift, *kotlin], lambda path: checks[os.path.splitext(path)[1]](path), VERIFY_PREFIX if from_verify() else "")


if __name__ == "__main__":
    if from_verify():
        run_gate("code-design-check", main, VERIFY_PREFIX)
    else:
        run_hook("code-design-check", main)
