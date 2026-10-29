#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/git.sh"
source "$(dirname "$0")/../../../lib/log.sh"

[[ $# -ge 2 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <確認の名前 | --drop <名前> | --status> [コマンド…]"; exit 1; }

use_repo "$1"
label=$2
shift 2
record=$(git_file "$repo" pr-checks)
lock="$record.lock"

update_record() {
    local drop=$1
    local line=${2:-}
    local tmp
    local tries=0

    until mkdir "$lock" 2>/dev/null; do
        if [[ -n $(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null) ]]; then
            rmdir "$lock" 2>/dev/null || true
            continue
        fi
        (( ++tries < 100 )) || { echo "NG 確認の記録のロックが外れない: $lock"; exit 1; }
        sleep 0.1
    done
    trap 'rmdir "$lock" 2>/dev/null' EXIT

    touch "$record"
    tmp=$(mktemp "$record.XXXXXX")
    awk -F '\t' -v label="$drop" '$2 != label' "$record" >| "$tmp"
    [[ -z $line ]] || printf '%s\n' "$line" >> "$tmp"
    mv -f "$tmp" "$record"
    rmdir "$lock"
    trap - EXIT
}

if [[ $label == --status ]]; then
    [[ -s $record ]] || { echo "NG run-check.sh で通した確認が無い"; exit 1; }
    state=$("$(dirname "$0")/hash-state.sh" "$repo") || { echo "NG ワークツリーの状態を読めない"; exit 1; }
    awk -F '\t' -v state="$state" '
        NF < 3 { next }
        $1 != "OK" { print "NG 通っていない確認: " $2; bad = 1; next }
        $3 != state { print "NG 確認の後に変更がある: " $2; bad = 1; next }
        { print "OK " $2 }
        END { exit bad }
    ' "$record"
    exit
fi

if [[ $label == --drop ]]; then
    [[ $# -ge 1 ]] || { echo "NG 外す確認の名前を渡す"; exit 1; }
    update_record "$1"
    echo "OK 外した: $1"
    exit 0
fi

[[ $# -gt 0 ]] || { echo "NG 確認のコマンドを渡す"; exit 1; }

logs=$(git_file "$repo" pr-check-logs)
log="$logs/${label//[^A-Za-z0-9._-]/_}.log"
mkdir -p "$logs"

status=0
(cd "$repo" && "$@") >| "$log" 2>&1 || status=$?
[[ $status == 0 ]] && result=OK || result=NG
state=$("$(dirname "$0")/hash-state.sh" "$repo") || { echo "NG ワークツリーの状態を読めない"; exit 1; }

update_record "$label" "$(printf '%s\t%s\t%s' "$result" "$label" "$state")"

if [[ $result == OK ]]; then
    rm -f "$log"
    echo "OK $label"
else
    echo "NG ${label}（終了コード ${status}）。ログ: $log"
    show_errors "$log"
    exit 1
fi
