import os
import re
import tempfile
import time
from pathlib import Path

SWEEP_INTERVAL = 60 * 60
SWEEP_MARK = ".swept"


def safe_name(text):
    return re.sub(r"[^A-Za-z0-9_-]", "_", text)


def state_folder(name):
    return os.path.join(tempfile.gettempdir(), f"claude-{name}")


def prepare_state(folder, age):
    os.makedirs(folder, exist_ok=True)
    mark = os.path.join(folder, SWEEP_MARK)
    try:
        if time.time() - os.path.getmtime(mark) < SWEEP_INTERVAL:
            return
    except OSError:
        pass
    remove_stale(folder, age)
    Path(mark).touch()


def is_stale(path, age):
    return time.time() - os.path.getmtime(path) > age


def remove_stale(folder, age):
    try:
        names = os.listdir(folder)
    except OSError:
        return
    for name in names:
        path = os.path.join(folder, name)
        try:
            if name == SWEEP_MARK:
                continue
            if not os.path.isdir(path):
                if is_stale(path, age):
                    os.remove(path)
                continue
            old = is_stale(path, age)
            for child in os.listdir(path):
                if is_stale(os.path.join(path, child), age):
                    os.remove(os.path.join(path, child))
            if old:
                os.rmdir(path)
        except OSError:
            continue
