#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hooks.sh"

payload="{\"tool_input\":{\"file_path\":\"$swift\"}}"
calls="$work/swiftformat-calls"

format() {
    echo "$payload" | bash "$hooks" swift-format 2>&1
    echo "status $?"
}

run swift-format 0 "swift: .swiftformat が無ければ何もしない" "$payload"

fake_command mint 'shift; exec "$@"'
fake_command swiftformat "echo \"\$PWD \$*\" >>'$calls'"
touch "$app/.swiftformat"
out=$(format)
check "swift: Mintfile が無ければ swiftformat を走らせない" test ! -e "$calls"
match "swift: Mintfile が無くても終了コード 0 で何も出さない" "$out" "status 0"

echo 'realm/SwiftLint@0.57.0' >"$app/Mintfile"
out=$(format)
check "swift: Mintfile に swiftformat が無ければ走らせない" test ! -e "$calls"
match "swift: Mintfile に swiftformat が無くても終了コード 0 で何も出さない" "$out" "status 0"

echo 'nicklockwood/SwiftFormat@0.54.6' >>"$app/Mintfile"
out=$(format)
match "swift: Mintfile で版を固定していれば終了コード 0 で通す" "$out" "status 0"
match "swift: mint で swiftformat をリポジトリの根で走らせる" "$(cat "$calls" 2>&1)" "*/app $swift"

fake_command swiftformat 'echo "壊れた設定" >&2; exit 1'
out=$(format)
match "swift: swiftformat が失敗したら、終了コード 0 のまま systemMessage で理由を知らせる" "$out" '{"systemMessage": "swiftformat が失敗した：壊れた設定"}'$'\n'"status 0"

fake_command swiftformat 'exec sleep 5'
out=$(python3 -I - "$root" "$swift" 2>&1 <<'EOF'
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
from loader import load_hook
hook = load_hook("swift-format")
hook.TIMEOUT = 1
hook.read_payload = lambda: {"tool_input": {"file_path": sys.argv[2]}}
hook.main()
print("exit 0")
EOF
)
match "swift: 時間切れなら、止めずに systemMessage で知らせる" "$out" '{"systemMessage": "swiftformat が 1 秒で終わらなかった"}'$'\n'"exit 0"

finish
