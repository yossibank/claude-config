export TMPDIR="$work/state/"
export HOME="$work/home"
mkdir -p "$TMPDIR" "$HOME"
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

# <フック> <期待の終了コード> <ラベル> <ファイルのパス> <中身> [期待する文]
# 中身を書いたファイルを編集した入力をフックに渡し、終了コードと出力の文を比べる。2 の時は文が要る
hook_case() {
    local hook=$1 expect=$2 label=$3 path=$4 text=$5 want=${6:-} out status
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$text" >"$path"
    out=$(file_call "$path" | bash "$hooks" "$hook" 2>&1)
    status=$?
    if [[ $status == "$expect" && $out == *"$want"* && ( $expect != 2 || -n $want ) ]]; then
        ok "$hook: $label"
    else
        ng "$hook: ${label}（終了コード ${status}、期待は ${expect} と「${want}」）" "$out"
    fi
}

edit() {
    jq -cn --arg session "$1" --arg agent "$2" --arg transcript "$3" --arg path "$4" \
        '{session_id: $session, agent_id: $agent, tool_name: "Edit", transcript_path: $transcript, tool_input: {file_path: $path}}'
}

read_rule() {
    jq -cn --arg session "$1" --arg agent "$2" --arg path "$rules/$3" \
        '{session_id: $session, agent_id: $agent, tool_name: "Read", tool_input: {file_path: $path}}' | bash "$hooks" rules-require-read
}

# <ファイルのパス> を編集した入力
file_call() {
    jq -cn --arg path "$1" '{tool_input: {file_path: $path}}'
}

# <tool_use_id> <コマンド> を $app で走らせた入力
bash_call() {
    jq -cn --arg id "$1" --arg cwd "$app" --arg command "$2" \
        '{session_id: "b", tool_use_id: $id, cwd: $cwd, tool_input: {command: $command}}'
}
