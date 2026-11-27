root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
while IFS= read -r name; do unset "$name"; done < <(compgen -e | grep '^CC_' || true)

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

match() {
    local label=$1 out=$2 pattern=$3
    if [[ $out == $pattern ]]; then
        ok "$label"
    else
        ng "$label" "$out"
    fi
}

replace_text() {
    local source=$1 dest=$2 old=$3 new=$4 text
    text=$(cat "$source"; echo x) || return 1
    text=${text%x}
    if [[ $text != *"$old"* ]]; then
        echo "置き換える語が無い: $old" >&2
        return 1
    fi
    printf '%s' "${text//"$old"/"$new"}" >"$dest"
}

PY_PRELUDE='import sys
sys.path.insert(0, sys.argv[1] + "/lib")
from loader import load_hook, load_module'
export PY_PRELUDE

make_apps() {
    local dir=$1 entry
    shift
    mkdir -p "$dir"
    for entry in "$@"; do
        mkdir -p "$dir/${entry%%=*}/store"
        echo "${entry#*=}" >"$dir/${entry%%=*}/store/app-id.txt"
    done
}

finish() {
    exit $((fails > 0))
}

offline() {
    export https_proxy=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9 http_proxy=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9
    export NO_PROXY= no_proxy=
}
