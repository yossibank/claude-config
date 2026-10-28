#!/bin/bash
set -uo pipefail

label=${1:?確認の名前を渡す}
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
echo "NG $label (full log: $log)"
exit "$status"
