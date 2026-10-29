root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

ok() {
    echo "OK $1"
}

ng() {
    echo "NG $1"
    [[ $# -lt 2 ]] || echo "$2" | head -5
    fails=$((fails + 1))
}

check() {
    local label=$1
    shift
    if "$@" >/dev/null; then
        ok "$label"
    else
        ng "$label"
    fi
}

expect() {
    local want=$1 label=$2 out status
    shift 2
    out=$("$@" 2>&1)
    status=$?
    if [[ $want == OK && $status == 0 ]] || [[ $want != OK && $status != 0 && $out == *"$want"* ]]; then
        ok "$label"
    else
        ng "${label}（終了コード ${status}、期待は ${want}）" "$out"
    fi
}

finish() {
    exit $((fails > 0))
}
