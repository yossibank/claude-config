import os
import re
import subprocess

PACKAGE = os.path.join(os.path.dirname(os.path.realpath(__file__)), "package")
BINARY = os.path.join(PACKAGE, ".build", "release", "swift-layout")
FINDING = re.compile(r"^(.*?):(\d+): (.*)$")
BUILD_TIMEOUT = 900
CHUNK = 200
STALE_MESSAGE = "swift-layout を組んでいないので、Swift の並びの検査を飛ばした。アプリの make verify で組まれる"


def sources():
    yield os.path.join(PACKAGE, "Package.swift")
    yield os.path.join(PACKAGE, "Package.resolved")
    for folder, _, names in os.walk(os.path.join(PACKAGE, "Sources")):
        for name in names:
            yield os.path.join(folder, name)


def is_stale():
    if not os.path.exists(BINARY):
        return True
    built = os.path.getmtime(BINARY)
    return any(os.path.exists(path) and os.path.getmtime(path) > built for path in sources())


def build():
    result = subprocess.run(
        ["swift", "build", "-c", "release", "--package-path", PACKAGE],
        capture_output=True,
        text=True,
        timeout=BUILD_TIMEOUT,
    )
    if result.returncode != 0:
        raise RuntimeError("swift-layout を組めなかった:\n" + (result.stderr or result.stdout)[-2000:])
    os.utime(BINARY)


def run(paths):
    findings = {}
    for start in range(0, len(paths), CHUNK):
        result = subprocess.run([BINARY, *paths[start : start + CHUNK]], capture_output=True, text=True, check=True)
        for line in result.stdout.splitlines():
            found = FINDING.match(line)
            if found:
                findings.setdefault(found.group(1), []).append((int(found.group(2)), found.group(3)))
    return findings


def fix_swift_layout(paths):
    if not paths:
        return
    if is_stale():
        build()
    for start in range(0, len(paths), CHUNK):
        subprocess.run([BINARY, "--fix", *paths[start : start + CHUNK]], check=True)


def check_swift_layout(paths, can_build):
    if not paths:
        return {}, ""
    if is_stale():
        if not can_build:
            return {}, STALE_MESSAGE
        build()
    return run(paths), ""
