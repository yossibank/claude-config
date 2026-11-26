import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "lib"))

from code_files import is_test, is_tooling  # noqa: E402
from hook_baseline import VERIFY_PREFIX, Baseline, from_verify  # noqa: E402
from hook_io import notify, run_gate, run_hook, target_paths  # noqa: E402
from hooks.kotlin_layout_check.runner import check_kotlin_layout, fix_kotlin_layout  # noqa: E402

HEADER = "Kotlin の並びの決まり（rules/kotlin-layout.md）に合わない箇所がある。直す。"
BASELINE = Baseline("kotlin-layout-baseline.txt")
FIX = "--fix"


def main():
    paths = [path for path in target_paths(".kt") if not is_tooling(path) and not is_test(path)]
    if FIX in sys.argv[1:]:
        fix_kotlin_layout(paths)
        return
    layout, skipped = check_kotlin_layout(paths, from_verify())
    if skipped:
        notify(skipped)
        return
    findings = [(path, line, message) for path in paths for line, message in layout.get(path, ())]
    BASELINE.report(HEADER, paths, findings)


if __name__ == "__main__":
    if from_verify():
        run_gate("kotlin-layout-check", main, VERIFY_PREFIX)
    else:
        run_hook("kotlin-layout-check", main)
