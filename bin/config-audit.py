import importlib
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "lib"))

from loader import ROOT  # noqa: E402
from script_io import fail, run_main  # noqa: E402

CHECKS_DIR = os.path.join(ROOT, "lib", "bin", "config_audit")
CHECK_PREFIX = "check_"


def checks():
    found = {}
    for file in sorted(os.listdir(CHECKS_DIR)):
        stem, extension = os.path.splitext(file)
        if extension != ".py":
            continue
        module = importlib.import_module(f"bin.config_audit.{stem}")
        for name, value in vars(module).items():
            if not name.startswith(CHECK_PREFIX) or not callable(value) or value.__module__ != module.__name__:
                continue
            label = name[len(CHECK_PREFIX) :].replace("_", "-")
            if label in found:
                fail(f"検査の名前が重なっている: {name}（lib/bin/config_audit/{file}）")
            found[label] = value
    return found


def main():
    available = checks()
    wanted = sys.argv[1:] or list(available)
    unknown = [name for name in wanted if name not in available]
    if unknown:
        fail(f"検査の名前が無い: {'、'.join(unknown)}。ある名前は {'、'.join(available)}")
    problems = [f"NG {os.path.relpath(path, ROOT)}:{line} {message}" for name in wanted for path, line, message in available[name]()]
    if problems:
        print("\n".join(problems))
        print(f"NG config-audit: {len(problems)} 件")
        sys.exit(1)
    print("OK config-audit")


if __name__ == "__main__":
    run_main(main)
