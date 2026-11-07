worktree_of() {
    git -C "$1" worktree list --porcelain \
        | awk -v want="branch refs/heads/$2" '/^worktree /{path=substr($0, 10)} $0 == want {print path}'
}
