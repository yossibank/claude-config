resolve_repo() {
    (cd "$1" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || {
        echo "NG Git のリポジトリではない: $1"
        return 1
    }
}

git_file() {
    git -C "$1" rev-parse --path-format=absolute --git-path "$2"
}

merge_base_of() {
    git -C "$1" merge-base "$2" HEAD 2>/dev/null || {
        echo "NG $2 との分かれ目が見つからない"
        return 1
    }
}

untracked_paths() {
    git -C "$1" ls-files -z --others --exclude-standard
}

changed_paths() {
    git -C "$1" diff --name-only -z "$2"
    untracked_paths "$1"
}

worktree_root() {
    echo "$HOME/.claude/worktrees/$1"
}

default_branch() {
    local head
    git -C "$1" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null && return 0
    head=$(git -C "$1" ls-remote --symref origin HEAD 2>/dev/null | awk '$1 == "ref:" && !found {sub("refs/heads/", "", $2); print $2; found = 1}') || true
    echo "origin/${head:-main}"
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
