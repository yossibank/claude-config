import os
import re
import shutil
import subprocess

HERE = os.path.dirname(os.path.realpath(__file__))
SOURCE = os.path.join(HERE, "source")
BUILD = os.path.join(HERE, ".build")
CLASSES = os.path.join(BUILD, "classes")
STAMP = os.path.join(BUILD, "ktlint-jar.txt")
MAIN = "KotlinLayout"
FINDING = re.compile(r"^(.*?):(\d+): (.*)$")
SCRIPT_JAVA_HOME = re.compile(r'JAVA_HOME="([^"]+)"')
SCRIPT_EXEC = re.compile(r'exec "([^"]+)"')
STUDIO_JAVA_HOME = "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
RELEASE = "17"
BUILD_TIMEOUT = 300
RUN_TIMEOUT = 600
CHUNK = 200
STALE_MESSAGE = "kotlin-layout を組んでいないので、Kotlin の並びの検査を飛ばした。アプリの make verify で組まれる"
NO_KTLINT_MESSAGE = "ktlint が無いので、Kotlin の並びの検査を飛ばした。ktlint を入れる"


def ktlint():
    """ktlint の jar と、ktlint のスクリプトが使う JAVA_HOME。"""
    script = shutil.which("ktlint")
    if not script:
        return None, None
    script = os.path.realpath(script)
    with open(script, "rb") as file:
        head = file.read(4096).decode("utf-8", "replace")
    home = SCRIPT_JAVA_HOME.search(head)
    target = SCRIPT_EXEC.search(head)
    jar = target.group(1) if target and os.path.isfile(target.group(1)) else script
    return jar, home.group(1) if home else None


def java_tools(script_home):
    """javac と java。ktlint の JAVA_HOME、Android Studio の JBR、PATH の順に探す。"""
    for home in filter(None, (script_home, STUDIO_JAVA_HOME)):
        javac = os.path.join(home, "bin", "javac")
        if os.path.isfile(javac):
            return javac, os.path.join(home, "bin", "java")
    javac = shutil.which("javac")
    return javac, shutil.which("java")


def sources():
    return [os.path.join(SOURCE, name) for name in sorted(os.listdir(SOURCE)) if name.endswith(".java")]


def built_jar():
    try:
        with open(STAMP, encoding="utf-8") as file:
            return file.read().strip()
    except OSError:
        return ""


def is_stale(jar):
    main = os.path.join(CLASSES, MAIN + ".class")
    if not os.path.exists(main) or built_jar() != jar:
        return True
    built = os.path.getmtime(main)
    return any(os.path.getmtime(path) > built for path in sources())


def build(jar, javac):
    if not javac:
        raise RuntimeError("javac が無いので、kotlin-layout を組めない。JDK を入れる")
    shutil.rmtree(CLASSES, ignore_errors=True)
    os.makedirs(CLASSES)
    result = subprocess.run(
        [javac, "--release", RELEASE, "-nowarn", "-cp", jar, "-d", CLASSES, *sources()],
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        timeout=BUILD_TIMEOUT,
    )
    if result.returncode != 0:
        raise RuntimeError("kotlin-layout を組めなかった:\n" + (result.stderr or result.stdout)[-2000:])
    with open(STAMP, "w", encoding="utf-8") as file:
        file.write(jar + "\n")


def command(jar, java):
    return [java, "-cp", os.pathsep.join([CLASSES, jar]), MAIN]


def run(base, paths):
    findings = {}
    for start in range(0, len(paths), CHUNK):
        result = subprocess.run(
            [*base, *paths[start : start + CHUNK]],
            capture_output=True,
            encoding="utf-8",
            check=True,
            timeout=RUN_TIMEOUT,
        )
        for line in result.stdout.splitlines():
            found = FINDING.match(line)
            if found:
                findings.setdefault(found.group(1), []).append((int(found.group(2)), found.group(3)))
    return findings


def prepared(can_build):
    """走らせるコマンドと、飛ばした理由。組めない時は、can_build なら組む。"""
    jar, script_home = ktlint()
    if not jar:
        if can_build:
            raise RuntimeError("ktlint が無いので、Kotlin の並びを確かめられない。ktlint を入れる")
        return None, NO_KTLINT_MESSAGE
    javac, java = java_tools(script_home)
    if is_stale(jar):
        if not can_build:
            return None, STALE_MESSAGE
        build(jar, javac)
    return command(jar, java), ""


def fix_kotlin_layout(paths):
    if not paths:
        return
    base, _ = prepared(True)
    for start in range(0, len(paths), CHUNK):
        subprocess.run(
            [*base, "--fix", *paths[start : start + CHUNK]], check=True, stderr=subprocess.DEVNULL, timeout=RUN_TIMEOUT
        )


def check_kotlin_layout(paths, can_build):
    if not paths:
        return {}, ""
    base, skipped = prepared(can_build)
    if skipped:
        return {}, skipped
    return run(base, paths), ""
