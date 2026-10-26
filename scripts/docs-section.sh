#!/bin/bash
set -euo pipefail

file=${1:?Markdown のパスを渡す}
heading=${2:-}

if [[ -z $heading ]]; then
    grep -n '^#' "$file"
    exit 0
fi

awk -v want="$heading" '
/^#+ / {
    match($0, /^#+/)
    level = RLENGTH
    if (found && level <= depth) exit
    if (substr($0, level + 2) == want) { found = 1; depth = level }
}
found
' "$file"
