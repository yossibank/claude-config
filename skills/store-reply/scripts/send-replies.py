import json
import os
import sys
import urllib.error
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from app_store import ASC_ERRORS, ASC_KEYS, asc_json, asc_reason, read_drafts, require_keys  # noqa: E402
from script_io import Failure, fail, run_main, write_json  # noqa: E402

LIMIT = 5970
USAGE = "使い方: send-replies.py <返信案の JSON> [--dry-run]"


def approved(entries):
    targets = [entry for entry in entries if entry.get("approved") is True and not entry.get("sent")]
    if not targets:
        raise Failure("承認されていて、まだ送っていない返信案が無い")
    for entry in targets:
        review = entry["id"]
        reply = entry.get("reply")
        if not isinstance(reply, str) or not reply.strip():
            raise Failure(f"返信が空: {review}")
        if len(reply) > LIMIT:
            raise Failure(f"返信が {LIMIT} 字を超えている（{len(reply)} 字）: {review}")
    return targets


def payload(entry):
    return {
        "data": {
            "type": "customerReviewResponses",
            "attributes": {"responseBody": entry["reply"]},
            "relationships": {"review": {"data": {"type": "customerReviews", "id": entry["id"]}}},
        }
    }


def existing_response(review):
    try:
        response = asc_json(f"/v1/customerReviews/{urllib.parse.quote(review, safe='')}/response")
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise
    data = response.get("data")
    return (data.get("id") or True) if data else None


def main():
    args = [arg for arg in sys.argv[1:] if arg != "--dry-run"]
    dry_run = len(args) < len(sys.argv) - 1
    if len(args) != 1:
        fail(USAGE)
    path = args[0]

    entries = read_drafts(path)
    targets = approved(entries)
    if not dry_run:
        require_keys(ASC_KEYS)

    if dry_run:
        for entry in targets:
            print(json.dumps(payload(entry), ensure_ascii=False))
        print(f"OK 送らずに {len(targets)} 件の中身を出した")
        return

    for entry in targets:
        label = f"{entry.get('app', '')} {entry['id']}"
        try:
            sent = existing_response(entry["id"])
            done = "返信が既にあるので送らなかった"
            if sent is None:
                sent = asc_json("/v1/customerReviewResponses", payload(entry)).get("data", {}).get("id") or True
                done = "送った"
        except ASC_ERRORS as error:
            fail(f"{label} を送れなかった: {asc_reason(error)}")
        entry["sent"] = sent
        write_json(path, entries)
        print(f"OK {label} {done}")


if __name__ == "__main__":
    run_main(main)
