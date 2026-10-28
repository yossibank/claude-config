import os
import plistlib
import re
import sys

REASONS = {
    "NSPrivacyAccessedAPICategoryUserDefaults": r"\bUserDefaults\b|@AppStorage\b",
    "NSPrivacyAccessedAPICategoryFileTimestamp": r"\.(creationDate|modificationDate|fileModificationDate)\b|\b(contentModificationDateKey|creationDateKey|attributesOfItem)\b",
    "NSPrivacyAccessedAPICategorySystemBootTime": r"\b(systemUptime|mach_absolute_time)\b",
    "NSPrivacyAccessedAPICategoryDiskSpace": r"\b(volumeAvailableCapacity\w*|volumeTotalCapacityKey|systemFreeSize|systemSize)\b",
    "NSPrivacyAccessedAPICategoryActiveKeyboards": r"\bactiveInputModes\b",
}
C_CALLS = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": ["stat", "lstat", "fstat", "fstatat", "getattrlist"],
    "NSPrivacyAccessedAPICategoryDiskSpace": ["statfs", "fstatfs", "statvfs", "fstatvfs"],
}
SKIP = {".build", ".swiftpm", "DerivedData", ".git", "Tests"}


def fail(message):
    print(f"NG {message}")
    sys.exit(1)


def declared_in(manifest):
    with open(manifest, "rb") as file:
        data = plistlib.load(file)
    return {
        item.get("NSPrivacyAccessedAPIType")
        for item in data.get("NSPrivacyAccessedAPITypes", [])
        if item.get("NSPrivacyAccessedAPITypeReasons")
    }


def manifest_for(path, root, manifests):
    directory = os.path.dirname(os.path.join(root, path))
    nearest = [m for m in manifests if directory.startswith(os.path.dirname(m) + os.sep) or directory == os.path.dirname(m)]
    if nearest:
        return [max(nearest, key=len)]
    return [m for m in manifests if f"{os.sep}Packages{os.sep}" not in m]


def main():
    if len(sys.argv) < 2:
        fail("使い方: privacy-check.py <アプリのリポジトリ>")

    root = sys.argv[1]
    used = {}
    manifests = []

    for directory, folders, files in os.walk(root):
        folders[:] = [f for f in folders if f not in SKIP and not f.endswith("Tests")]
        for file in files:
            path = os.path.join(directory, file)
            if file == "PrivacyInfo.xcprivacy":
                manifests.append(path)
            if not file.endswith(".swift"):
                continue
            text = open(path, encoding="utf-8", errors="ignore").read()
            for category, pattern in REASONS.items():
                calls = [
                    name for name in C_CALLS.get(category, [])
                    if re.search(rf"\b{name}\s*\(", text) and not re.search(rf"\bfunc\s+{name}\b", text)
                ]
                if re.search(pattern, text) or calls:
                    used.setdefault(category, []).append(os.path.relpath(path, root))

    ok = True
    if not manifests:
        print("NG PrivacyInfo.xcprivacy が無い")
        ok = False
    declared = {m: declared_in(m) for m in manifests}
    for category, paths in sorted(used.items()):
        missing = [p for p in paths if not any(category in declared[m] for m in manifest_for(p, root, manifests))]
        mark = "NG" if missing else "OK"
        ok = ok and not missing
        print(f"{mark} {category}（{len(paths)} ファイル。例: {(missing or paths)[0]}）")
    for category in sorted(set().union(*declared.values()) - used.keys()):
        print(f"-- {category} は申告しているが、コードに見つからない")

    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
