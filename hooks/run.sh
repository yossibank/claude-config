#!/bin/bash
set -uo pipefail

hook="$(dirname "$0")/${1:-}.py"
[[ $# -ge 1 && -f $hook ]] || { echo "NG フックが無い: ${hook}。claude-config を ~/Applications/AI/claude-config に置き、config-install.sh を走らせ直す" >&2; exit 1; }
[[ " ${CLAUDE_HOOKS_OFF:-} " == *" $1 "* ]] && exit 0
shift
exec python3 -I "$hook" "$@"
