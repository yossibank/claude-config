#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

scripts="$root/skills/store-reply/scripts"
export https_proxy=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9
unset ASC_ISSUER_ID ASC_KEY_ID ASC_KEY_PATH ASC_VENDOR_NUMBER

apps="$work/apps"
mkdir -p "$apps/foo/store" "$apps/bar/store" "$work/none"
echo 123 >"$apps/foo/store/app-id.txt"
echo abc >"$apps/bar/store/app-id.txt"

expect "使い方" "collect-reviews: 余計な引数は NG" python3 -I "$scripts/collect-reviews.py" 123
CC_APPS_DIR="$apps" expect "環境変数が無い: ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH" "collect-reviews: キーが無ければ NG" python3 -I "$scripts/collect-reviews.py"
export ASC_ISSUER_ID=x ASC_KEY_ID=y ASC_KEY_PATH="$work/none.p8"
CC_APPS_DIR="$work/none" expect "store/app-id.txt を持つアプリが無い" "collect-reviews: アプリが無ければ NG" python3 -I "$scripts/collect-reviews.py"
out=$(CC_APPS_DIR="$apps" python3 -I "$scripts/collect-reviews.py" 2>&1)
check "collect-reviews: どのアプリも読めなければ NG" grep -q "^NG どのアプリのレビューも集められなかった" <<<"$out"
check "collect-reviews: 数字でないアプリの ID は通信せずに知らせる" grep -q "bar のレビューは集められなかった（NG アプリの ID は数字で書く: abc）" <<<"$out"
check "collect-reviews: 通信できないアプリを知らせる" grep -q "foo のレビューは集められなかった（NG レビューを読めなかった" <<<"$out"

collected=$(CC_APPS_DIR="$apps" python3 -I - "$root" "$scripts/collect-reviews.py" 2>/dev/null <<'EOF'
import glob
import json
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
from loader import load_module

module = load_module(sys.argv[2])
review = lambda id, rating, answered: {
    "id": id,
    "attributes": {"rating": rating, "title": f"t{id}", "body": f"b{id}", "createdDate": "2026-10-01T20:00:00-07:00", "territory": "JPN"},
    "relationships": {"response": {"data": {"type": "customerReviewResponses", "id": "r"} if answered else None}},
}
pages = {
    module.reviews_url("123"): {"data": [review("a", 1, False), review("b", 2, True)], "links": {"next": "https://next"}},
    "https://next": {"data": [review("c", 2, False), review("d", 4, False)], "links": {}},
}
module.asc_json = lambda url, body=None: pages[url]
sys.argv = ["collect-reviews.py"]
module.main()
path = glob.glob(module.apps_dir() + "/replies/*.json")[0]
entries = json.load(open(path, encoding="utf-8"))
entries[0]["reply"] = "書きかけ"
json.dump(entries, open(path, "w", encoding="utf-8"), ensure_ascii=False)
module.main()
entries = json.load(open(path, encoding="utf-8"))
print(" ".join(f"{e['id']}:{e['rating']}:{e['date']}:{e['reply']}:{e['approved']}" for e in entries))
EOF
)
check "collect-reviews: 返信済みと星 3 以上を除き、次のページも読む" grep -q "^a:1:2026-10-02:書きかけ:False c:2:2026-10-02::False$" <<<"$collected"
check "collect-reviews: 集め直しても書きかけの案を残す" grep -q "a:1:2026-10-02:書きかけ" <<<"$collected"

drafts="$work/drafts.json"
cat >"$drafts" <<'EOF'
[
  {"app": "foo", "id": "a", "reply": "ご不便をおかけしました。", "approved": true},
  {"app": "foo", "id": "b", "reply": "未承認", "approved": false},
  {"app": "foo", "id": "c", "reply": "送り済み", "approved": true, "sent": "r1"}
]
EOF

unset ASC_ISSUER_ID ASC_KEY_ID ASC_KEY_PATH
expect "使い方" "send-replies: 引数が無ければ NG" python3 -I "$scripts/send-replies.py"
expect "使い方" "send-replies: 引数が多ければ NG" python3 -I "$scripts/send-replies.py" "$drafts" extra
expect "返信案のファイルが無い" "send-replies: ファイルが無ければ NG" python3 -I "$scripts/send-replies.py" "$work/missing.json"
echo '{' >"$work/broken.json"
expect "JSON として読めない" "send-replies: 壊れた JSON は NG" python3 -I "$scripts/send-replies.py" "$work/broken.json"
echo '[{"id": "x", "reply": "r", "approved": false}]' >"$work/none-approved.json"
expect "承認されていて、まだ送っていない返信案が無い" "send-replies: 承認された案が無ければ NG" python3 -I "$scripts/send-replies.py" "$work/none-approved.json" --dry-run
python3 -I -c 'import json, sys; json.dump([{"id": "x", "reply": "あ" * 5971, "approved": True}], open(sys.argv[1], "w"))' "$work/long.json"
expect "5970 字を超えている" "send-replies: 5970 字を超える案は NG" python3 -I "$scripts/send-replies.py" "$work/long.json" --dry-run
echo '[{"id": "x", "reply": " ", "approved": true}]' >"$work/empty.json"
expect "返信が空: x" "send-replies: 空の案は NG" python3 -I "$scripts/send-replies.py" "$work/empty.json" --dry-run
expect "環境変数が無い" "send-replies: --dry-run でなければキーが要る" python3 -I "$scripts/send-replies.py" "$drafts"

before=$(cat "$drafts")
dry=$(python3 -I "$scripts/send-replies.py" --dry-run "$drafts")
check "send-replies: --dry-run はキーも通信も無しで終える" test $? -eq 0
check "send-replies: --dry-run は承認された未送信の案だけを出す" test "$(grep -c '^{' <<<"$dry")" -eq 1
check "send-replies: --dry-run はファイルを書き換えない" test "$before" = "$(cat "$drafts")"

shape=$(python3 -I - "$(head -1 <<<"$dry")" <<'EOF'
import json
import sys
want = {"data": {"type": "customerReviewResponses", "attributes": {"responseBody": "ご不便をおかけしました。"}, "relationships": {"review": {"data": {"type": "customerReviews", "id": "a"}}}}}
print(json.loads(sys.argv[1]) == want)
EOF
)
check "send-replies: 送る JSON は customerReviewResponses の形" test "$shape" = True

sent=$(ASC_ISSUER_ID=x ASC_KEY_ID=y ASC_KEY_PATH=z python3 -I - "$root" "$scripts/send-replies.py" "$drafts" <<'EOF'
import json
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
from loader import load_module

module = load_module(sys.argv[2])
drafts = sys.argv[3]
calls = []
module.asc_json = lambda url, body=None: calls.append((url, body)) or {"data": {"id": "new"}}
sys.argv = ["send-replies.py", drafts]
module.main()
entries = json.load(open(drafts, encoding="utf-8"))
print(len(calls), calls[0][0], calls[0][1]["data"]["relationships"]["review"]["data"]["id"], entries[0].get("sent"), entries[1].get("sent"))
EOF
)
check "send-replies: 承認された未送信の案だけを POST し、sent に返信の ID を書く" grep -q "^1 /v1/customerReviewResponses a new None$" <<<"$sent"

finish
