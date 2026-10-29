import sys

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
