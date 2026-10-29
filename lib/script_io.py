import sys


class Failure(Exception):
    pass


def fail(message):
    print(f"NG {message}")
    sys.exit(1)
