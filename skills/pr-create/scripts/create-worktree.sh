#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/git.sh"

[[ $# -ge 2 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <ブランチ名>"; exit 1; }

use_repo "$1"
branch=$2

if ! [[ $branch =~ ^(feat|fix|docs|refactor|test|build|ci|chore)/[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "NG ブランチ名が <type>/<summary> の形ではない: $branch"
    exit 1
fi

git -C "$repo" fetch -q origin || { echo "NG origin から fetch できない"; exit 1; }
base=$(default_branch "$repo")
dest="$(worktree_root "$(basename "$repo")")/${branch//\//-}"

[[ ! -e $dest ]] || { echo "NG ワークツリーの行き先が既にある: $dest"; exit 1; }
git -C "$repo" worktree add -q "$dest" -b "$branch" "$base" || { echo "NG ワークツリーを作れない: ${branch}（${base} から）"; exit 1; }
echo "$dest"
