import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "lib"))

from code_files import is_test, is_tooling  # noqa: E402
from hook_baseline import VERIFY_PREFIX, Baseline, from_verify  # noqa: E402
from hook_io import notify, run_gate, run_hook, target_paths  # noqa: E402
from hooks.swift_layout_check.runner import check_swift_layout, fix_swift_layout  # noqa: E402

HEADER = "Swift の並びの決まり（rules/swift-layout.md）に合わない箇所がある。直す。"
BASELINE = Baseline("swift-layout-baseline.txt")
FIX = "--fix"


def main():
    paths = [path for path in target_paths(".swift") if not is_tooling(path) and not is_test(path)]
    if FIX in sys.argv[1:]:
        fix_swift_layout(paths)
        return
    layout, skipped = check_swift_layout(paths, from_verify())
    if skipped:
        notify(skipped)
        return
    findings = [(path, line, message) for path in paths for line, message in layout.get(path, ())]
    BASELINE.report(HEADER, paths, findings)


if __name__ == "__main__":
    if from_verify():
        run_gate("swift-layout-check", main, VERIFY_PREFIX)
    else:
        run_hook("swift-layout-check", main)
