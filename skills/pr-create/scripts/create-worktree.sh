#!/bin/bash
set -euo pipefail

[[ $# -ge 2 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス> <ブランチ名>"; exit 1; }

repo=$(cd "$1" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || { echo "NG Git のリポジトリではない: $1"; exit 1; }
branch=$2

if ! [[ $branch =~ ^(feat|fix|docs|refactor|test|build|ci|chore)/[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "NG ブランチ名が <type>/<summary> の形ではない: $branch"
    exit 1
fi

git -C "$repo" fetch -q origin
base=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
dest="$HOME/.claude/worktrees/$(basename "$repo")/${branch//\//-}"

git -C "$repo" worktree add -q "$dest" -b "$branch" "$base"
echo "$dest"
