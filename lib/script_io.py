import json
import os
import sys
import tempfile

from dates import MONTH


class Failure(Exception):
    pass


def fail(message):
    print(f"NG {message}")
    sys.exit(1)


def require_month(arg, usage):
    if arg is None:
        fail(usage)
    if not MONTH.fullmatch(arg):
        fail(f"月は YYYY-MM で書く: {arg}")
    return arg


def write_json(path, data):
    folder = os.path.dirname(os.path.abspath(path))
    os.makedirs(folder, exist_ok=True)
    handle, temporary = tempfile.mkstemp(dir=folder, suffix=".tmp")
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as file:
            file.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        os.replace(temporary, path)
    except BaseException:
        os.unlink(temporary)
        raise
