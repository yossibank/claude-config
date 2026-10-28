#!/bin/bash
set -euo pipefail

repo=$(cd "${1:?リポジトリのパスを渡す}" && git rev-parse --show-toplevel)
index=$(mktemp)
trap 'rm -f "$index"' EXIT

cp "$(git -C "$repo" rev-parse --path-format=absolute --git-path index)" "$index"
GIT_INDEX_FILE=$index git -C "$repo" add -A
GIT_INDEX_FILE=$index git -C "$repo" write-tree | cut -c1-12
