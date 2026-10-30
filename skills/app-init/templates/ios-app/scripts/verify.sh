#!/bin/bash
set -uo pipefail

[[ $# -ge 1 ]] || { echo "NG 使い方: $(basename "$0") <確認の名前>"; exit 1; }

label=$1
shift
[[ $# -gt 0 ]] || { echo "NG $label: コマンドを渡す"; exit 1; }

mkdir -p .build/verify
log=".build/verify/$label.log"
"$@" >|"$log" 2>&1
status=$?

if [[ $status -eq 0 ]]; then
    rm -f "$log"
    echo "OK $label"
    exit 0
fi

grep -E "error:|failed|Test Case .* failed|✖" "$log" | sort -u | head -40
echo "NG ${label}（ログ: ${log}）"
exit "$status"
