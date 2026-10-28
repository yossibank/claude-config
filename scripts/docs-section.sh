#!/bin/bash
set -euo pipefail

file=${1:?Markdown のパスを渡す}
heading=${2:-}

awk -v want="$heading" '
function fence_length(line, mark,    rest) {
    rest = line
    sub(/^ +/, "", rest)
    if (length(line) - length(rest) > 3 || substr(rest, 1, 1) != mark) return 0
    match(rest, "^" mark "+")
    return RLENGTH >= 3 ? RLENGTH : 0
}
{
    if (open_mark != "") {
        n = fence_length($0, open_mark)
        rest = $0
        sub(/^ *[`~]+ *$/, "", rest)
        if (n >= open_length && rest == "") open_mark = ""
        if (found) print
        next
    }
    for (i = 1; i <= 2; i++) {
        mark = i == 1 ? "`" : "~"
        n = fence_length($0, mark)
        if (n) { open_mark = mark; open_length = n; break }
    }
    if (open_mark != "") { if (found) print; next }
}
/^#+ / {
    match($0, /^#+/)
    level = RLENGTH
    if (want == "") { print NR ":" $0; next }
    if (found && level <= depth) exit
    if (substr($0, level + 2) == want) { found = 1; depth = level }
}
found
END { if (want != "" && !found) { print "NG 見出しが無い: " want > "/dev/stderr"; exit 1 } }
' "$file"
