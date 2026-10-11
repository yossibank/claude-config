#!/bin/bash
set -euo pipefail

repo=$(cd "${1:?リポジトリのパスを渡す}" && git rev-parse --show-toplevel)
branch=${2:?ブランチ名を渡す}
pr=${3:-}
name=$(basename "$repo")

fail() {
    echo "NG $name: $1" >&2
    exit 1
}

if [[ -n $pr ]]; then
    state=$(cd "$repo" && gh pr view "$pr" --json state -q .state)
    [[ $state == MERGED ]] || fail "PR #$pr が MERGED ではない（$state）"
fi

main=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
main=${main#origin/}
[[ $(git -C "$repo" branch --show-current) == "$main" ]] || fail "手元が $main ではない"
[[ -z $(git -C "$repo" status --porcelain) ]] || fail "手元に未 commit の変更がある"
git -C "$repo" pull -q --ff-only origin "$main" || fail "pull --ff-only が通らない"
[[ $(git -C "$repo" rev-parse HEAD) == $(git -C "$repo" rev-parse "origin/$main") ]] \
    || fail "手元の $main に、origin に無い commit がある"

if git -C "$repo" rev-parse -q --verify "refs/heads/$branch" >/dev/null; then
    if ! git -C "$repo" diff --quiet "origin/$main" "$branch"; then
        base=$(git -C "$repo" merge-base "origin/$main" "$branch")
        git -C "$repo" diff "$base" "$branch" | git -C "$repo" apply -R --check 2>/dev/null \
            || fail "$branch の中身が $main に入っていない。ワークツリーとブランチは残した"
    fi
    worktree=$(git -C "$repo" worktree list --porcelain \
        | awk -v want="branch refs/heads/$branch" '/^worktree /{path=substr($0, 10)} $0 == want {print path}')
    [[ -z $worktree ]] || git -C "$repo" worktree remove "$worktree"
    git -C "$repo" branch -q -D "$branch"
fi

git -C "$repo" fetch -q --prune origin
remote=$(git -C "$repo" ls-remote --heads origin "$branch" | wc -l | tr -d ' ')
[[ $remote == 0 ]] && left="なし" || left="残っている"
echo "OK $name: $(git -C "$repo" rev-parse --short HEAD) | 手元の $main は origin と一致 | GitHub 上のブランチ: $left"
