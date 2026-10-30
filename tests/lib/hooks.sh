export TMPDIR="$work/state/"
mkdir -p "$TMPDIR"
hooks="$root/hooks/run.sh"
run_check="$root/skills/pr-create/scripts/run-check.sh"
rules="$root/rules"

app="$work/app"
mkdir -p "$app/ios/Features" "$app/docs"
echo 'struct A {}' >"$app/ios/Features/HomeView.swift"
echo '# 概要' >"$app/docs/overview.md"
echo '{}' >"$app/data.json"
git -C "$app" init -q
commit "$app" init
swift="$app/ios/Features/HomeView.swift"

run() {
    local hook=$1 expect=$2 label=$3 payload=$4 out status
    shift 4
    out=$(echo "$payload" | bash "$hooks" "$hook" "$@" 2>&1)
    status=$?
    if [[ $status == "$expect" ]]; then
        ok "$label"
    else
        ng "${label}（終了コード ${status}、期待は ${expect}）" "$out"
    fi
}

edit() {
    echo "{\"session_id\":\"$1\",\"agent_id\":\"$2\",\"tool_name\":\"Edit\",\"transcript_path\":\"$3\",\"tool_input\":{\"file_path\":\"$4\"}}"
}

read_rule() {
    echo "{\"session_id\":\"$1\",\"agent_id\":\"$2\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$rules/$3\"}}" | bash "$hooks" rules-require-read
}

bash_call() {
    echo "{\"session_id\":\"b\",\"tool_use_id\":\"$1\",\"cwd\":\"$app\",\"tool_input\":{\"command\":\"$2\"}}"
}
