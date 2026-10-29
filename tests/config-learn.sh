#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

export TMPDIR="$work/state/"
mkdir -p "$TMPDIR"
hooks="$root/hooks/run.sh"
collect="$root/skills/config-learn/scripts/collect-corrections.py"

app="$work/app"
mkdir -p "$app/ios/Features" "$app/docs"
echo 'struct A {}' >"$app/ios/Features/HomeView.swift"
echo '# 概要' >"$app/docs/overview.md"
git -C "$app" init -q
commit "$app" init
swift="$app/ios/Features/HomeView.swift"
: >"$work/empty.jsonl"

bash_call() {
    echo "{\"session_id\":\"b\",\"tool_use_id\":\"$1\",\"cwd\":\"$app\",\"tool_input\":{\"command\":\"$2\"}}"
}

expect "NG 使い方" "collect: 月が無ければ NG" python3 -I "$collect"

blocked_rules=$(echo "{\"session_id\":\"s9\",\"agent_id\":\"main\",\"tool_name\":\"Edit\",\"transcript_path\":\"$work/empty.jsonl\",\"tool_input\":{\"file_path\":\"$swift\"}}" | bash "$hooks" rules-require-read 2>&1)
bash_call t9 'sed -i x' | bash "$hooks" rules-detect-bash-edits pre
echo '# 変更' >>"$app/docs/overview.md"
blocked_bash=$(bash_call t9 'sed -i x' | bash "$hooks" rules-detect-bash-edits post 2>&1)
blocked_pr=$(echo "{\"cwd\":\"$app\",\"tool_input\":{\"command\":\"git push\"}}" | bash "$hooks" pr-gate 2>&1)
projects="$work/home/.claude/projects"
mkdir -p "$projects/demo"
python3 -I - "$projects/demo/s.jsonl" "$work" "$swift" "$app" "$blocked_rules" "$blocked_bash" "$blocked_pr" <<'EOF'
import json, sys
path, cwd, swift, app, rules, bash, pr = sys.argv[1:]
stamp = "2026-10-01T00:00:00.000Z"


def use(id, name, tool_input, where=cwd):
    return {"type": "assistant", "timestamp": stamp, "cwd": where, "message": {"content": [{"type": "tool_use", "id": id, "name": name, "input": tool_input}]}}


def result(id, text):
    return {"type": "user", "timestamp": stamp, "cwd": cwd, "message": {"content": [{"type": "tool_result", "tool_use_id": id, "is_error": True, "content": text}]}}


rows = [
    use("e1", "Edit", {"file_path": swift}),
    result("e1", "PreToolUse:Edit hook error: " + rules),
    use("b1", "Bash", {"command": "sed -i x docs/overview.md"}, app),
    {"type": "attachment", "timestamp": stamp, "cwd": app, "attachment": {"type": "hook_blocking_error", "toolUseID": "b1", "blockingError": {"blockingError": "[hook] " + bash}}},
    use("p1", "Bash", {"command": f"git -C {app} push"}),
    result("p1", "PreToolUse:Bash hook error: " + pr),
    result("g1", "Exit code 2\n" + app + "/hooks/x.py:1: " + rules),
]
text = "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows)
open(path, "w").write(text + text)
EOF
touch -t 202610150000 "$projects/demo/s.jsonl"
report=$(CC_PROJECTS_DIR="$projects" python3 -I "$collect" 2026-10)
if grep -q '^| app | 1 | 1 | 1 | 1 |$' <<<"$report"; then
    ok "collect: 3 つのフックが止めた回数を数える"
else
    ng "collect: 3 つのフックが止めた回数を数える" "$(grep "^|" <<<"$report")"
fi

finish
