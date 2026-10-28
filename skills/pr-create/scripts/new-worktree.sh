#!/bin/bash
set -euo pipefail

repo=$(cd "${1:?リポジトリのパスを渡す}" && git rev-parse --show-toplevel)
branch=${2:?ブランチ名を渡す}

if ! [[ $branch =~ ^(feat|fix|docs|refactor|test|build|ci|chore)/[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "NG ブランチ名が <type>/<summary> の形ではない: $branch"
    exit 1
fi

git -C "$repo" fetch -q origin
base=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
dest="$HOME/.claude/worktrees/$(basename "$repo")/${branch//\//-}"

git -C "$repo" worktree add -q "$dest" -b "$branch" "$base"
echo "$dest"
