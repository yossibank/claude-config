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

expect "使い方" "fetch-unreplied-reviews: 余計な引数は NG" python3 -I "$scripts/fetch-unreplied-reviews.py" 123
CC_APPS_DIR="$apps" expect "環境変数が無い: ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH" "fetch-unreplied-reviews: キーが無ければ NG" python3 -I "$scripts/fetch-unreplied-reviews.py"
export ASC_ISSUER_ID=x ASC_KEY_ID=y ASC_KEY_PATH="$work/none.p8"
CC_APPS_DIR="$work/none" expect "store/app-id.txt を持つアプリが無い" "fetch-unreplied-reviews: アプリが無ければ NG" python3 -I "$scripts/fetch-unreplied-reviews.py"
out=$(CC_APPS_DIR="$apps" python3 -I "$scripts/fetch-unreplied-reviews.py" 2>&1)
check "fetch-unreplied-reviews: どのアプリも読めなければ NG" grep -q "^NG どのアプリのレビューも集められなかった" <<<"$out"
check "fetch-unreplied-reviews: 数字でないアプリの ID は通信せずに知らせる" grep -q "bar のレビューは集められなかった（NG アプリの ID は数字で書く: abc）" <<<"$out"
check "fetch-unreplied-reviews: 通信できないアプリを知らせる" grep -q "foo のレビューは集められなかった（NG レビューを読めなかった" <<<"$out"

collected=$(CC_APPS_DIR="$apps" python3 -I - "$root" "$scripts/fetch-unreplied-reviews.py" 2>/dev/null <<'EOF'
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
sys.argv = ["fetch-unreplied-reviews.py"]
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
check "fetch-unreplied-reviews: 返信済みと星 3 以上を除き、次のページも読む" grep -q "^a:1:2026-10-02:書きかけ:False c:2:2026-10-02::False$" <<<"$collected"
check "fetch-unreplied-reviews: 集め直しても書きかけの案を残す" grep -q "a:1:2026-10-02:書きかけ" <<<"$collected"
check "fetch-unreplied-reviews: 一時ファイルを残さない" test -z "$(find "$apps/replies" -name '*.tmp')"
kept=$(CC_APPS_DIR="$apps" python3 -I - "$root" "$scripts/fetch-unreplied-reviews.py" 2>/dev/null <<'EOF'
import glob
import json
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
from loader import load_module

module = load_module(sys.argv[2])
module.asc_json = lambda url, body=None: {"data": [], "links": {}}
path = glob.glob(module.apps_dir() + "/replies/*.json")[0]
drafts = [{"app": "bar", "id": "z", "reply": "案", "approved": True}, {"app": "foo", "id": "y", "reply": "古い", "approved": False}]
json.dump(drafts, open(path, "w", encoding="utf-8"), ensure_ascii=False)
sys.argv = ["fetch-unreplied-reviews.py"]
module.main()
print(" ".join(f"{e['id']}:{e['reply']}" for e in json.load(open(path, encoding="utf-8"))))
EOF
)
check "fetch-unreplied-reviews: 集められなかったアプリの案は残し、集めたアプリの古い案は外す" test "${kept##*$'\n'}" == "z:案"

today="$apps/replies/$(TZ=Asia/Tokyo date +%F).json"
echo '[{"id": "a",' >"$today"
CC_APPS_DIR="$apps" expect "返信案のファイルが JSON として読めない" "fetch-unreplied-reviews: 壊れた案のファイルは集める前に NG" python3 -I "$scripts/fetch-unreplied-reviews.py"
echo '[{"reply": "id が無い"}]' >"$today"
CC_APPS_DIR="$apps" expect "返信案の 1 件目にレビューの id が無い" "fetch-unreplied-reviews: id の無い項目は NG" python3 -I "$scripts/fetch-unreplied-reviews.py"
echo '{"id": "a"}' >"$today"
CC_APPS_DIR="$apps" expect "返信案のファイルはレビューの配列にする" "fetch-unreplied-reviews: 配列でない案のファイルは NG" python3 -I "$scripts/fetch-unreplied-reviews.py"

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

sending="$work/sending.json"
cat >"$sending" <<'EOF'
[
  {"app": "foo", "id": "a", "reply": "ご不便をおかけしました。", "approved": true},
  {"app": "foo", "id": "b", "reply": "未承認", "approved": false},
  {"app": "foo", "id": "e", "reply": "返信済み", "approved": true}
]
EOF
sent=$(ASC_ISSUER_ID=x ASC_KEY_ID=y ASC_KEY_PATH=z python3 -I - "$root" "$scripts/send-replies.py" "$sending" <<'EOF'
import json
import sys
import urllib.error
sys.path.insert(0, sys.argv[1] + "/lib")
from loader import load_module

module = load_module(sys.argv[2])
drafts = sys.argv[3]
calls = []


def fake(url, body=None):
    calls.append(("POST" if body else "GET", url, body))
    if body:
        return {"data": {"id": "new"}}
    if url == "/v1/customerReviews/a/response":
        raise urllib.error.HTTPError(url, 404, "Not Found", None, None)
    return {"data": {"type": "customerReviewResponses", "id": "old"}}


module.asc_json = fake
sys.argv = ["send-replies.py", drafts]
module.main()
entries = json.load(open(drafts, encoding="utf-8"))
print(" ".join(f"{method}:{url}" for method, url, _ in calls))
print(calls[1][2]["data"]["relationships"]["review"]["data"]["id"])
print(" ".join(str(entry.get("sent")) for entry in entries))
EOF
)
check "send-replies: 送る前に返信の有無を確かめ、無いレビューだけを POST する" \
    grep -qx "GET:/v1/customerReviews/a/response POST:/v1/customerReviewResponses GET:/v1/customerReviews/e/response" <<<"$sent"
check "send-replies: POST の中身は確かめたレビューを指す" grep -qx "a" <<<"$sent"
check "send-replies: 返信が既にあれば送らずに、その返信の ID を sent に書く" grep -qx "new None old" <<<"$sent"
check "send-replies: 返信が既にあったことを知らせる" grep -q "^OK foo e 返信が既にあるので送らなかった" <<<"$sent"
check "send-replies: 一時ファイルを残さない" test -z "$(find "$work" -maxdepth 1 -name '*.tmp')"

finish
