#!/bin/bash
set -uo pipefail

repo=$(cd "${1:?リポジトリのパスを渡す}" && git rev-parse --show-toplevel)
label=${2:?確認の名前を渡す}
shift 2
[[ $# -gt 0 ]] || { echo "NG 確認のコマンドを渡す"; exit 1; }

record=$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-checks)
logs=$(git -C "$repo" rev-parse --path-format=absolute --git-path pr-check-logs)
log="$logs/${label//[^A-Za-z0-9._-]/_}.log"
mkdir -p "$logs"
touch "$record"

(cd "$repo" && "$@") >| "$log" 2>&1
status=$?
[[ $status == 0 ]] && result=OK || result=NG
state=$("$(dirname "$0")/state.sh" "$repo")

awk -F '\t' -v label="$label" '$2 != label' "$record" >| "$record.new"
printf '%s\t%s\t%s\n' "$result" "$label" "$state" >> "$record.new"
mv -f "$record.new" "$record"

if [[ $result == OK ]]; then
    rm -f "$log"
    echo "OK $label"
else
    echo "NG ${label}（終了コード ${status}）。ログ: $log"
    grep -E -i 'error|fail' "$log" | tail -n 20
    exit 1
fi
