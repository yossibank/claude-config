commit() {
    git -C "$1" add -A
    git -C "$1" -c user.name=t -c user.email=t@t commit -q -m "$2"
}

clone_with_origin() {
    local repo=$1

    git init -q --bare -b main "$repo.git"
    git clone -q "$repo.git" "$repo" 2>/dev/null
    echo a >"$repo/a.md"
    commit "$repo" init
    git -C "$repo" push -q origin main
    git -C "$repo" remote set-head origin main
}

fake_gh() {
    fake_command gh "$1"
}

fake_command() {
    mkdir -p "$work/bin"
    if [[ $2 == '#!'* ]]; then
        printf '%s\n' "$2" >"$work/bin/$1"
    else
        printf '#!/bin/bash\n%s\n' "$2" >"$work/bin/$1"
    fi
    chmod +x "$work/bin/$1"
    [[ :$PATH: == *":$work/bin:"* ]] || export PATH="$work/bin:$PATH"
}
