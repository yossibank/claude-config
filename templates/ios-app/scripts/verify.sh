#!/bin/bash
set -uo pipefail

log=$(mktemp -t verify)
"$@" >|"$log" 2>&1
status=$?

if [[ $status -eq 0 ]]; then
    echo "OK $1 (log: $log)"
    exit 0
fi

grep -E "error:|failed|Test Case .* failed|✖" "$log" | sort -u | head -40
echo "NG $1 (full log: $log)"
exit "$status"
