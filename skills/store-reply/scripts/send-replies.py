import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "lib"))

from app_store import ASC_ERRORS, ASC_KEYS, asc_json, asc_reason, require_keys  # noqa: E402
from script_io import Failure, fail  # noqa: E402

LIMIT = 5970
USAGE = "使い方: send-replies.py <返信案の JSON> [--dry-run]"


def load(path):
    try:
        entries = json.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise Failure(f"返信案のファイルが無い: {path}") from error
    except ValueError as error:
        raise Failure(f"返信案のファイルが JSON として読めない: {path}") from error
    if not isinstance(entries, list) or not all(isinstance(entry, dict) for entry in entries):
        raise Failure(f"返信案のファイルはレビューの配列にする: {path}")
    return entries


def approved(entries):
    targets = [entry for entry in entries if entry.get("approved") is True and not entry.get("sent")]
    if not targets:
        raise Failure("承認されていて、まだ送っていない返信案が無い")
    for entry in targets:
        review = entry.get("id")
        reply = entry.get("reply")
        if not isinstance(review, str) or not review:
            raise Failure(f"レビューの id が無い: {entry.get('app', '')}")
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


def save(path, entries):
    Path(path).write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    args = [arg for arg in sys.argv[1:] if arg != "--dry-run"]
    dry_run = len(args) < len(sys.argv) - 1
    if len(args) != 1:
        fail(USAGE)
    path = args[0]

    try:
        entries = load(path)
        targets = approved(entries)
        if not dry_run:
            require_keys(ASC_KEYS)
    except Failure as error:
        fail(str(error))

    if dry_run:
        for entry in targets:
            print(json.dumps(payload(entry), ensure_ascii=False))
        print(f"OK 送らずに {len(targets)} 件の中身を出した")
        return

    for entry in targets:
        try:
            response = asc_json("/v1/customerReviewResponses", payload(entry))
        except ASC_ERRORS as error:
            save(path, entries)
            fail(f"{entry.get('app', '')} {entry['id']} を送れなかった: {asc_reason(error)}")
        entry["sent"] = response.get("data", {}).get("id") or True
        save(path, entries)
        print(f"OK {entry.get('app', '')} {entry['id']}")


if __name__ == "__main__":
    main()
