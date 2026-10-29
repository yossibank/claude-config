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
    mkdir -p "$work/bin"
    printf '#!/bin/bash\n%s\n' "$1" >"$work/bin/gh"
    chmod +x "$work/bin/gh"
    [[ :$PATH: == *":$work/bin:"* ]] || export PATH="$work/bin:$PATH"
}
