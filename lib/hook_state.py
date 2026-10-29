import os
import re
import time


def safe_name(text):
    return re.sub(r"[^A-Za-z0-9_-]", "_", text)


def remove_stale(folder, age):
    try:
        names = os.listdir(folder)
    except OSError:
        return
    for name in names:
        path = os.path.join(folder, name)
        try:
            if time.time() - os.path.getmtime(path) > age:
                if os.path.isdir(path):
                    for child in os.listdir(path):
                        os.remove(os.path.join(path, child))
                    os.rmdir(path)
                else:
                    os.remove(path)
        except OSError:
            continue
