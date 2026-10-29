resolve_repo() {
    (cd "$1" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || {
        echo "NG Git のリポジトリではない: $1"
        return 1
    }
}

git_file() {
    git -C "$1" rev-parse --path-format=absolute --git-path "$2"
}

worktree_root() {
    echo "$HOME/.claude/worktrees/$1"
}

default_branch() {
    git -C "$1" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main
}

repo_access() {
    local info owner name permission

    info=$(cd "$1" && gh repo view --json owner,name,viewerPermission \
        -q '"\(.owner.login) \(.name) \(.viewerPermission)"') || {
        echo "NG gh repo view が通らない"
        return 1
    }
    read -r owner name permission <<< "$info"

    case $permission in
        ADMIN | MAINTAIN | WRITE) echo "$owner $name write" ;;
        *) echo "$owner $name read" ;;
    esac
}

use_repo() {
    repo=$(resolve_repo "$1") || {
        echo "$repo"
        exit 1
    }
}
