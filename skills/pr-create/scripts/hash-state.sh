#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/git.sh"

[[ $# -ge 1 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス>"; exit 1; }

use_repo "$1"
index=$(mktemp)
trap 'rm -f "$index"' EXIT

cp "$(git -C "$repo" rev-parse --path-format=absolute --git-path index)" "$index"
GIT_INDEX_FILE=$index git -C "$repo" add -A
GIT_INDEX_FILE=$index git -C "$repo" write-tree | cut -c1-12
