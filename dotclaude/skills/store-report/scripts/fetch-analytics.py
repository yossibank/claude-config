import csv
import gzip
import io
import json
import os
import sys
import urllib.request
import zlib
from datetime import date, timedelta

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "..", "lib"))

from store_api import ASC_ERRORS, ASC_KEYS, asc_json, asc_pages, asc_reason, require_app_id, require_keys  # noqa: E402
from script_io import Failure, fail, require_month, run_main  # noqa: E402

ACCESS = ["ONGOING", "ONE_TIME_SNAPSHOT"]
ENGAGEMENT = "App Store Discovery and Engagement Standard"
DOWNLOADS = "App Downloads Standard"
STAGES = ["impressions", "page_views", "downloads"]
SOURCES = {
    "App Store search": "App Store の検索",
    "App Store browse": "App Store の閲覧",
    "App referrer": "参照元アプリ",
    "Web referrer": "参照元ウェブ",
    "Institutional purchase": "法人購買",
    "Unavailable": "参照元なし",
}
WAIT = "まだ分析のレポートが無い。依頼から 1〜2 日で届く"


def month_range(month):
    first = date.fromisoformat(f"{month}-01")
    next_month = (first.replace(day=28) + timedelta(days=4)).replace(day=1)
    return first, next_month - timedelta(days=1)


def previous_month(month):
    first, _ = month_range(month)
    return (first - timedelta(days=1)).strftime("%Y-%m")


def report_requests(app_id):
    requests = {}
    for page in asc_pages(f"/v1/apps/{app_id}/analyticsReportRequests"):
        for item in page["data"]:
            attributes = item["attributes"]
            if attributes["accessType"] == "ONGOING" and attributes.get("stoppedDueToInactivity"):
                continue
            requests.setdefault(attributes["accessType"], item["id"])
    created = []
    for access in ACCESS:
        if access in requests:
            continue
        body = {"data": {
            "type": "analyticsReportRequests",
            "attributes": {"accessType": access},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }}
        requests[access] = asc_json("/v1/analyticsReportRequests", body=body)["data"]["id"]
        created.append(access)
    return [requests[access] for access in ACCESS], created


def report_ids(request_id):
    return {
        item["attributes"]["name"]: item["id"]
        for page in asc_pages(f"/v1/analyticsReportRequests/{request_id}/reports")
        for item in page["data"]
    }


def instance_ids(report_id, window, granularity="DAILY"):
    ids = []
    for page in asc_pages(f"/v1/analyticsReports/{report_id}/instances?filter[granularity]={granularity}"):
        for item in page["data"]:
            day = item["attributes"].get("processingDate", "")
            if window is None or window[0] <= day <= window[1]:
                ids.append(item["id"])
    return ids


def read_segment(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read()
    return gzip.decompress(data).decode("utf-8") if data[:2] == b"\x1f\x8b" else data.decode("utf-8")


def parse_rows(text):
    header = text.split("\n", 1)[0]
    return list(csv.DictReader(io.StringIO(text), delimiter="\t" if "\t" in header else ","))


def report_rows(report_id, window, granularity="DAILY"):
    rows = []
    for instance in instance_ids(report_id, window, granularity):
        for page in asc_pages(f"/v1/analyticsReportInstances/{instance}/segments"):
            for item in page["data"]:
                rows += parse_rows(read_segment(item["attributes"]["url"]))
    return rows


def rows_by_day(rows):
    days = {}
    for row in rows:
        days.setdefault(row["Date"], []).append(row)
    return days


def count(row):
    return int(float(row.get("Counts") or 0))


def stage_of(row):
    if "Event" in row:
        event = row["Event"].lower()
        if "impression" in event:
            return "impressions"
        if "page view" in event:
            return "page_views"
        return None
    return "downloads" if row.get("Download Type", "").lower().startswith("first") else None


def summarize(rows, first, last):
    days = {}
    sources = {}
    for row in rows:
        day = row["Date"]
        stage = stage_of(row)
        if stage is None or not first.isoformat() <= day <= last.isoformat():
            continue
        value = count(row)
        days.setdefault(day, dict.fromkeys(STAGES, 0))[stage] += value
        source = row.get("Source Type") or "不明"
        sources.setdefault(source, dict.fromkeys(STAGES, 0))[stage] += value
    totals = {stage: sum(day[stage] for day in days.values()) for stage in STAGES}
    return {"totals": totals, "days": dict(sorted(days.items())), "sources": sources}


def merged_rows(request_ids, name, windows, delivered):
    merged = {}
    for request_id, window in zip(request_ids, windows):
        report = report_ids(request_id).get(name)
        if report is None:
            continue
        rows = report_rows(report, window)
        if rows:
            delivered.add(request_id)
        for day, day_rows in rows_by_day(rows).items():
            merged.setdefault(day, day_rows)
    return [row for rows in merged.values() for row in rows]


def monthly_rows(request_ids, name):
    """月ごとの分を、月ごとに最初に届いた依頼のものだけ返す。"""
    merged = {}
    for request_id in request_ids:
        report = report_ids(request_id).get(name)
        if report is None:
            continue
        by_month = {}
        for row in report_rows(report, None, "MONTHLY"):
            by_month.setdefault(row["Date"][:7], []).append(row)
        for month, rows in by_month.items():
            merged.setdefault(month, rows)
    return merged


def cumulative(monthly, daily_rows, month, current):
    """公開から今月までの累計。月ごとの分が無い月は、日ごとの分で埋める。"""
    by_month = {key: rows for key, rows in monthly.items() if key < month}
    for row in daily_rows:
        key = row["Date"][:7]
        if key < month and key not in monthly:
            by_month.setdefault(f"daily-{key}", []).append(row)
    totals = dict(current["totals"])
    starts = list(current["days"])[:1]
    for key, rows in by_month.items():
        counted = False
        for row in rows:
            stage = stage_of(row)
            if stage is not None:
                totals[stage] += count(row)
                counted = True
        if counted:
            starts.append(min(row["Date"] for row in rows))
    return {"totals": totals, "since": min(starts) if starts else None}


def coverage_notices(days, first, last, today):
    expected = min(last, today - timedelta(days=1))
    if not days or (date.fromisoformat(days[0]) <= first and date.fromisoformat(days[-1]) >= expected):
        return []
    return [f"掲載の数字は {days[0]}〜{days[-1]} の {len(days)} 日分だけ（{first.isoformat()}〜{expected.isoformat()} のうち）"]


def funnel(app_id, month, today=None):
    require_keys(ASC_KEYS)
    require_app_id(app_id)
    first, last = month_range(month)
    previous_first, previous_last = month_range(previous_month(month))
    try:
        request_ids, created = report_requests(app_id)
        windows = [(previous_first.isoformat(), (last + timedelta(days=7)).isoformat()), None]
        delivered = set()
        rows = merged_rows(request_ids, ENGAGEMENT, windows, delivered) + merged_rows(request_ids, DOWNLOADS, windows, delivered)
        current = summarize(rows, first, last)
        previous = summarize(rows, previous_first, previous_last)
        monthly = {}
        for name in (ENGAGEMENT, DOWNLOADS):
            for key, month_rows in monthly_rows(request_ids, name).items():
                monthly.setdefault(key, []).extend(month_rows)
        total = cumulative(monthly, rows, month, current)
    except (*ASC_ERRORS, EOFError, zlib.error) as error:
        raise Failure(f"分析のレポートを読めなかった: {asc_reason(error)}") from error
    except (KeyError, ValueError) as error:
        raise Failure(f"分析のレポートの中身が想定と違う（{type(error).__name__}: {error}）") from error
    notices = []
    if created:
        notices.append(f"分析のレポートの依頼（{'・'.join(created)}）を作った")
    if request_ids[1] not in delivered and "ONE_TIME_SNAPSHOT" not in created:
        notices.append("過去の分の依頼（ONE_TIME_SNAPSHOT）の数字は、まだ届いていない")
    if not current["days"]:
        notices.append(WAIT)
        return None, notices
    notices += coverage_notices(list(current["days"]), first, last, today or date.today())
    return {"month": current, "previous": previous if previous["days"] else None, "total": total}, notices


def main():
    usage = "使い方: fetch-analytics.py <アプリの ID> <YYYY-MM>"
    if len(sys.argv) < 3:
        fail(usage)
    require_keys(ASC_KEYS)
    month = require_month(sys.argv[2], usage)
    result, notices = funnel(sys.argv[1], month)
    for notice in notices:
        print(notice, file=sys.stderr)
    if result is None:
        raise Failure(WAIT)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    run_main(main)
