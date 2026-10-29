import datetime
import re

JST = datetime.timezone(datetime.timedelta(hours=9))
MONTH = re.compile(r"[0-9]{4}-(0[1-9]|1[0-2])")


def to_jst(stamp):
    return datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone(JST)


def month_start(month):
    return datetime.datetime.strptime(month, "%Y-%m").replace(tzinfo=JST)


def month_of(stamp):
    return to_jst(stamp).strftime("%Y-%m")
