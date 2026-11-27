import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "lib"))

import kotlin_source  # noqa: E402
import swift_source  # noqa: E402
from hooks.code_design_check.clones import Clones  # noqa: E402
from hooks.code_design_check.effect import check_kotlin_effect, check_swift_effect  # noqa: E402
from hooks.code_design_check.flags import check_kotlin_flags, check_swift_flags  # noqa: E402
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
from hooks.code_design_check.modules import is_open_to  # noqa: E402
from hooks.code_design_check.names import check_swift_role, check_swift_suffix  # noqa: E402
from hooks.code_design_check.slots import check_kotlin_bare, check_kotlin_slots, check_swift_bare, check_swift_slots, check_unread_fields  # noqa: E402
from hooks.code_design_check.shape import check_kotlin_shape, check_swift_shape  # noqa: E402
from hooks.code_design_check.state import (  # noqa: E402
    KOTLIN_NOW,
    SWIFT_NOW,
    check_kotlin_clock,
    check_kotlin_input,
    check_kotlin_output,
    check_kotlin_state,
    check_now,
    check_passage,
    check_swift_clock,
    check_swift_dependencies,
    check_swift_input,
    check_swift_output,
    check_swift_state,
)
from hooks.code_design_check.view import check_kotlin_view, check_swift_view  # noqa: E402
from hook_baseline import VERIFY_PREFIX, Baseline, from_verify  # noqa: E402
from hook_io import run_gate, run_hook, target_paths  # noqa: E402

HEADER = "設計の決まり（rules/code-design.md）に合わない箇所がある。直す。"
BASELINE = Baseline("code-design-baseline.txt")


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
                *check_swift_role(path, code, clones.root_of(os.path.realpath(path))),
                *check_swift_suffix(path, code),
                *check_folder(path, ".swift", folders),
                *check_parts(path, code, clones.root_of(os.path.realpath(path))),
                *check_swift_state(code),
                *check_swift_flags(code),
                *check_swift_slots(code),
                *check_swift_bare(code),
                *check_unread_fields(path, code),
                *check_swift_shape(code),
                *check_swift_output(code),
                *check_swift_clock(code),
                *(check_swift_input(code) if is_open_to(path, "input") else ()),
                *(check_swift_dependencies(code) if is_open_to(path, "dependencies") else ()),
                *check_passage(code),
                *check_swift_view(path, code),
                *check_swift_effect(path, code),
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
                *check_kotlin_flags(code),
                *check_kotlin_slots(code),
                *check_kotlin_bare(code),
                *check_unread_fields(path, code),
                *check_kotlin_shape(code),
                *check_kotlin_output(code),
                *check_kotlin_clock(code),
                *(check_kotlin_input(code) if is_open_to(path, "input") else ()),
                *check_passage(code),
                *check_kotlin_view(path, code),
                *check_kotlin_effect(path, code),
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


def main():
    paths = [path for path in target_paths("") if not is_tooling(path)]
    BASELINE.report(HEADER, paths, findings_of(paths))


if __name__ == "__main__":
    if from_verify():
        run_gate("code-design-check", main, VERIFY_PREFIX)
    else:
        run_hook("code-design-check", main)
