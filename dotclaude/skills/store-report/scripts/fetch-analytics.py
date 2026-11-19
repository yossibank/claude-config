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


def instance_ids(report_id, window):
    ids = []
    for page in asc_pages(f"/v1/analyticsReports/{report_id}/instances?filter[granularity]=DAILY"):
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


def report_rows(report_id, window):
    rows = []
    for instance in instance_ids(report_id, window):
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


def merged_rows(request_ids, name, windows):
    merged = {}
    for request_id, window in zip(request_ids, windows):
        report = report_ids(request_id).get(name)
        if report is None:
            continue
        for day, rows in rows_by_day(report_rows(report, window)).items():
            merged.setdefault(day, rows)
    return [row for rows in merged.values() for row in rows]


def funnel(app_id, month):
    require_keys(ASC_KEYS)
    require_app_id(app_id)
    first, last = month_range(month)
    previous_first, previous_last = month_range(previous_month(month))
    try:
        request_ids, created = report_requests(app_id)
        windows = [(previous_first.isoformat(), (last + timedelta(days=7)).isoformat()), None]
        rows = merged_rows(request_ids, ENGAGEMENT, windows) + merged_rows(request_ids, DOWNLOADS, windows)
        current = summarize(rows, first, last)
        previous = summarize(rows, previous_first, previous_last)
    except (*ASC_ERRORS, EOFError, zlib.error) as error:
        raise Failure(f"分析のレポートを読めなかった: {asc_reason(error)}") from error
    except (KeyError, ValueError) as error:
        raise Failure(f"分析のレポートの中身が想定と違う（{type(error).__name__}: {error}）") from error
    notices = []
    if created:
        notices.append(f"分析のレポートの依頼（{'・'.join(created)}）を作った")
    if not current["days"]:
        notices.append(WAIT)
        return None, notices
    return {"month": current, "previous": previous if previous["days"] else None}, notices


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
