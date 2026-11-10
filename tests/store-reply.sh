#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/support/assert.sh"
source "$(dirname "$0")/support/http_fake.sh"

scripts="$root/dotclaude/skills/store-reply/scripts"
offline
unset ASC_ISSUER_ID ASC_KEY_ID ASC_KEY_PATH ASC_VENDOR_NUMBER

apps="$work/apps"
mkdir -p "$work/none"
make_apps "$apps" foo=123 bar=abc

expect "使い方" "fetch-unreplied-reviews: 余計な引数は NG" python3 -I "$scripts/fetch-unreplied-reviews.py" 123
CC_APPS_DIR="$apps" expect "環境変数が無い: ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH" "fetch-unreplied-reviews: キーが無ければ NG" python3 -I "$scripts/fetch-unreplied-reviews.py"
export ASC_ISSUER_ID=x ASC_KEY_ID=y ASC_KEY_PATH="$work/none.p8"
CC_APPS_DIR="$work/none" expect "store/app-id.txt を持つアプリが無い" "fetch-unreplied-reviews: アプリが無ければ NG" python3 -I "$scripts/fetch-unreplied-reviews.py"
out=$(CC_APPS_DIR="$apps" python3 -I "$scripts/fetch-unreplied-reviews.py" 2>&1)
check "fetch-unreplied-reviews: どのアプリも読めなければ NG" grep -q "^NG どのアプリのレビューも集められなかった" <<<"$out"
check "fetch-unreplied-reviews: 数字でないアプリの ID は通信せずに知らせる" grep -q "bar のレビューは集められなかった（NG アプリの ID は数字で書く: abc）" <<<"$out"
check "fetch-unreplied-reviews: 通信できないアプリを知らせる" grep -q "foo のレビューは集められなかった（NG レビューを読めなかった" <<<"$out"

asc_keys
collected=$(CC_APPS_DIR="$apps" python3 -I - "$root" "$scripts/fetch-unreplied-reviews.py" 2>/dev/null <<'EOF'
import glob
import json
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

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
install(lambda method, url, body: pages.get(url))
sys.argv = ["fetch-unreplied-reviews.py"]
try:
    module.main()
except SystemExit:
    pass
path = glob.glob(module.apps_dir() + "/replies/*.json")[0]
entries = json.load(open(path, encoding="utf-8"))
entries[0]["reply"] = "書きかけ"
json.dump(entries, open(path, "w", encoding="utf-8"), ensure_ascii=False)
try:
    module.main()
except SystemExit:
    pass
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
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

module = load_module(sys.argv[2])
install(lambda method, url, body: {"data": [], "links": {}})
path = glob.glob(module.apps_dir() + "/replies/*.json")[0]
drafts = [{"app": "bar", "id": "z", "reply": "案", "approved": True}, {"app": "foo", "id": "y", "reply": "古い", "approved": False}]
json.dump(drafts, open(path, "w", encoding="utf-8"), ensure_ascii=False)
sys.argv = ["fetch-unreplied-reviews.py"]
try:
    module.main()
except SystemExit:
    pass
print(" ".join(f"{e['id']}:{e['reply']}" for e in json.load(open(path, encoding="utf-8"))))
EOF
)
check "fetch-unreplied-reviews: 集められなかったアプリの案は残し、集めたアプリの古い案は外す" test "${kept##*$'\n'}" == "z:案"

unexpected=$(CC_APPS_DIR="$apps" python3 -I - "$root" "$scripts/fetch-unreplied-reviews.py" 2>/dev/null <<'EOF'
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

module = load_module(sys.argv[2])
install(lambda method, url, body: {"data": [{"id": "a", "attributes": {"rating": 1}, "relationships": {}}], "links": {}})
sys.argv = ["fetch-unreplied-reviews.py"]
module.run_main(module.main)
EOF
)
status=$?
check "fetch-unreplied-reviews: 想定外の例外は stdout に NG を出して終了コード 1" test "$status" -eq 1 -a "$(grep -c '^NG .*想定外の失敗（KeyError' <<<"$unexpected")" -eq 1

partial=$(CC_APPS_DIR="$apps" python3 -I - "$root" "$scripts/fetch-unreplied-reviews.py" 2>/dev/null <<'EOF'
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

module = load_module(sys.argv[2])
install(lambda method, url, body: {"data": [], "links": {}})
sys.argv = ["fetch-unreplied-reviews.py"]
module.run_main(module.main)
EOF
)
status=$?
check "fetch-unreplied-reviews: 一部のアプリが失敗したら stdout に NG を出して終了コード 1" test "$status" -eq 1 -a "$(grep -c '^NG .*bar（アプリの ID は数字で書く: abc）.*replies' <<<"$partial")" -eq 1
check "fetch-unreplied-reviews: 一部が失敗しても集めた分は書く" test -f "$apps/replies/$(TZ=Asia/Tokyo date +%F).json"
check "fetch-unreplied-reviews: 一部が失敗した時は OK の行を出さない" test -z "$(grep '^OK' <<<"$partial")"

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
jq -n --arg reply "$(printf 'あ%.0s' $(seq 5971))" '[{id: "x", reply: $reply, approved: true}]' >"$work/long.json"
jq -n --arg reply "$(printf 'あ%.0s' $(seq 5970))" '[{id: "x", reply: $reply, approved: true}]' >"$work/limit.json"
expect OK "send-replies: 5970 字ちょうどの案は通る" python3 -I "$scripts/send-replies.py" "$work/limit.json" --dry-run
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
asc_keys
sent=$(python3 -I - "$root" "$scripts/send-replies.py" "$sending" <<'EOF'
import json
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

module = load_module(sys.argv[2])
drafts = sys.argv[3]


def route(method, url, body):
    if method == "POST" and url == "/v1/customerReviewResponses":
        return {"data": {"id": "new"}}
    if url == "/v1/customerReviews/a/response":
        return (404, "{}")
    if url == "/v1/customerReviews/e/response":
        return {"data": {"type": "customerReviewResponses", "id": "old"}}
    return None


install(route)
sys.argv = ["send-replies.py", drafts]
module.main()
entries = json.load(open(drafts, encoding="utf-8"))
print(" ".join(f"{method}:{url}" for method, url, _ in requests))
print(requests[1][2]["data"]["relationships"]["review"]["data"]["id"])
print(" ".join(str(entry.get("sent")) for entry in entries))
report_unknown()
EOF
)
check "send-replies: 知らない URL に触れない" test -z "$(grep UNKNOWN <<<"$sent")"
check "send-replies: 送る前に返信の有無を確かめ、無いレビューだけを POST する" \
    grep -qx "GET:/v1/customerReviews/a/response POST:/v1/customerReviewResponses GET:/v1/customerReviews/e/response" <<<"$sent"
check "send-replies: POST の中身は確かめたレビューを指す" grep -qx "a" <<<"$sent"
check "send-replies: 返信が既にあれば送らずに、その返信の ID を sent に書く" grep -qx "new None old" <<<"$sent"
check "send-replies: 返信が既にあったことを知らせる" grep -q "^OK foo e 返信が既にあるので送らなかった" <<<"$sent"
check "send-replies: 一時ファイルを残さない" test -z "$(find "$work" -maxdepth 1 -name '*.tmp')"

cat >|"$work/err.json" <<'EOF'
[{"app": "foo", "id": "a", "reply": "返信", "approved": true}]
EOF
failed=$(python3 -I - "$root" "$scripts/send-replies.py" "$work/err.json" <<'EOF'
import json
import os
import sys
exec(os.environ["PY_PRELUDE"])
exec(os.environ["HTTP_FAKE_PY"])

module = load_module(sys.argv[2])
install(lambda method, url, body: (500, json.dumps({"errors": [{"detail": "混んでいる"}]})))
sys.argv = ["send-replies.py", sys.argv[3]]
module.run_main(module.main)
EOF
)
check "send-replies: 404 以外の HTTPError は理由を入れた NG にして、sent を書かない" grep -qx "NG foo a を送れなかった: 500: 混んでいる" <<<"$failed"
check "send-replies: 送れなかった案に sent を書かない" test -z "$(grep sent "$work/err.json")"

reason=$(python3 -I - "$root" <<'EOF'
import json
import os
import sys
import urllib.error
sys.path.insert(0, sys.argv[1] + "/lib")
exec(os.environ["HTTP_FAKE_PY"])
import store_api

install(lambda method, url, body: (409, json.dumps({"errors": [{"detail": "返信が長すぎる"}]})))
try:
    store_api.asc_request("/v1/x")
except urllib.error.HTTPError as error:
    print(store_api.asc_reason(error))
EOF
)
check "asc_reason: HTTPError の本文の detail を理由に入れる" test "$reason" == "409: 返信が長すぎる"

mode=$(python3 -I - "$root" "$work/json/out.json" <<'EOF'
import os
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
from script_io import write_json

write_json(sys.argv[2], {"a": 1})
print(oct(os.stat(sys.argv[2]).st_mode & 0o777))
EOF
)
check "write_json: 書いたファイルは 0644 にする" test "$mode" == 0o644

# 署名の DER を読む処理（lib/store_api.py）
der=$(python3 -I - "$root" 2>&1 <<'EOF'
import base64
import os
import sys
exec(os.environ["PY_PRELUDE"])
import store_api

r = bytes([0x00, 0x80] + [1] * 31)
s = bytes([2] * 32)
body = bytes([0x02, len(r)]) + r + bytes([0x02, len(s)]) + s
short = bytes([0x30, len(body)]) + body
raw = store_api.raw_signature(short)
print(len(raw), raw[:32] == r[1:], raw[32:] == s)
short_r = bytes([0x02, 1, 7]) + bytes([0x02, len(s)]) + s
raw = store_api.raw_signature(bytes([0x30, len(short_r)]) + short_r)
print(raw[:32] == bytes(31) + bytes([7]))
long_body = bytes([0x30, 0x81, len(body)]) + body
print(len(store_api.raw_signature(long_body)))
for bad in (b"", b"\x30", bytes([0x30, 3, 0x04, 1, 0])):
    try:
        store_api.raw_signature(bad)
    except ValueError as error:
        print("ValueError", error)
header, payload, signature = store_api.token().split(".")
print(len(base64.urlsafe_b64decode(signature + "==")))
EOF
)
check "raw_signature: 先頭の 0 を落として 32 バイトずつに詰め、長い形の長さも読む" grep -qx "64 True True" <<<"$der"
check "raw_signature: 短い整数は 0 で埋める" grep -qx "True" <<<"$der"
check "raw_signature: 壊れた DER は ValueError にする" grep -qx "ValueError openssl の署名が空" <<<"$der"
check "raw_signature: 整数の形でない DER は ValueError にする" grep -q "ValueError openssl の署名が DER の整数の形でない" <<<"$der"
check "token: 本物の鍵で署名した JWT の署名は 64 バイト" test "$(tail -1 <<<"$der")" -eq 64

finish
