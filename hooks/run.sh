#!/bin/bash
set -uo pipefail

here=$(dirname "$0")
hook="${here}/${1:-}.py"
[[ $# -ge 1 && -f $hook ]] || { echo "NG フックが無い: ${hook}。claude-config を ~/Applications/AI/claude-config に置き、config-install.sh を走らせ直す" >&2; exit 1; }
off=${CC_HOOKS_OFF:-}
read -ra names <<<"${off//[,$'\t'$'\n']/ }"
unknown=()
for name in ${names[@]+"${names[@]}"}; do
    [[ -f "${here}/${name}.py" ]] || unknown+=("$name")
done
[[ ${#unknown[@]} -eq 0 ]] || echo "CC_HOOKS_OFF に hooks/ に無い名前がある: ${unknown[*]}" >&2
for name in ${names[@]+"${names[@]}"}; do
    [[ $name == "$1" ]] && exit 0
done
shift
exec python3 -I "$hook" "$@"
