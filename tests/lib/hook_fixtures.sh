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

gate_failed="フックが確かめられなかったので止める"

# 終了コード 2 を期待する時は、STOP に止めた理由の文を入れる。フックが例外で落ちた時の 2 とは区別する
run() {
    local hook=$1 expect=$2 label=$3 payload=$4 out status
    shift 4
    out=$(echo "$payload" | bash "$hooks" "$hook" "$@" 2>&1)
    status=$?
    if [[ $status != "$expect" ]]; then
        ng "${label}（終了コード ${status}、期待は ${expect}）" "$out"
    elif [[ $expect == 2 && $out == *"$gate_failed"* ]]; then
        ng "${label}（フックが例外で落ちた）" "$out"
    elif [[ $expect == 2 && ( -z ${STOP:-} || $out != *"$STOP"* ) ]]; then
        ng "${label}（止めた理由の文に「${STOP:-}」が無い）" "$out"
    else
        ok "$label"
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
