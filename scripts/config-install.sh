#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
claude="$HOME/.claude"
settings="$claude/settings.json"
trap 'rm -f "$settings.tmp"' EXIT

link() {
    local source=$1
    local dest=$2

    if [[ -L $dest ]]; then
        ln -sfn "$source" "$dest"
    elif [[ -e $dest ]]; then
        echo "NG $dest が実体としてある。退避してから実行し直す" >&2
        exit 1
    else
        ln -s "$source" "$dest"
    fi

    echo "OK リンク: $dest"
}

mkdir -p "$claude/skills"

link "$root/CLAUDE.md" "$claude/CLAUDE.md"
link "$root/rules" "$claude/rules"
link "$root/agents" "$claude/agents"

for skill in "$root"/skills/*/; do
    link "${skill%/}" "$claude/skills/$(basename "$skill")"
done

for dest in "$claude"/skills/*; do
    if [[ -L $dest && ! -e $dest ]]; then
        rm "$dest"
        echo "OK 壊れたリンクを消した: $dest"
    fi
done

if [[ ! -f $settings ]]; then
    echo '{}' >|"$settings"
fi

jq -s '
    .[0] as $current
    | .[1] as $config
    | $current
    | .permissions.allow = (($current.permissions.allow // []) + $config.permissions.allow | unique)
    | .hooks = $config.hooks
' "$settings" "$root/settings/settings.json" >|"$settings.tmp"
mv -f "$settings.tmp" "$settings.new"

if diff -u "$settings" "$settings.new"; then
    rm "$settings.new"
    echo "OK settings.json は変わらない"
else
    echo "確かめてから置き換える: mv \"$settings.new\" \"$settings\""
fi
