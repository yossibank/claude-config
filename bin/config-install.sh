#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
expected="$HOME/Applications/AI/claude-config"
claude="$HOME/.claude"
dotclaude="$root/dotclaude"

if [[ $root != "$expected" ]]; then
    echo "NG claude-config が $root にある。決まりとスキルは $expected のスクリプトを指すので、そこに置いてから実行する"
    exit 1
fi
if ! command -v jq >/dev/null; then
    echo "NG jq が見つからない。settings.json の案を作るのに要るので、入れてから実行し直す"
    exit 1
fi
settings="$claude/settings.json"
installed="$claude/claude-config-allow.json"
trap 'rm -f "$settings.tmp" "$settings.old.sorted" "$settings.new.sorted"' EXIT

link() {
    local source=$1
    local dest=$2

    if [[ -L $dest ]]; then
        ln -sfn "$source" "$dest"
    elif [[ -e $dest ]]; then
        echo "NG $dest が実体としてある。退避してから実行し直す"
        exit 1
    else
        ln -s "$source" "$dest"
    fi

    echo "OK リンク: $dest"
}

mkdir -p "$claude/skills" "$claude/output-styles"

link "$dotclaude/CLAUDE.md" "$claude/CLAUDE.md"
link "$dotclaude/rules" "$claude/rules"
link "$dotclaude/agents" "$claude/agents"
link "$dotclaude/hooks" "$claude/hooks"

for skill in "$dotclaude"/skills/*/; do
    link "${skill%/}" "$claude/skills/$(basename "$skill")"
done

for style in "$dotclaude"/output-styles/*.md; do
    link "$style" "$claude/output-styles/$(basename "$style")"
done

for dest in "$claude"/skills/* "$claude"/output-styles/*; do
    if [[ -L $dest && ! -e $dest ]]; then
        rm "$dest"
        echo "OK 壊れたリンクを消した: $dest"
    fi
done

if [[ ! -f $settings ]]; then
    echo '{}' >|"$settings"
fi

if [[ ! -f $installed ]]; then
    echo '[]' >|"$installed"
fi

jq -s -f "$root/lib/config_install/settings.jq" "$settings" "$dotclaude/settings.json" "$installed" >|"$settings.tmp"
mv -f "$settings.tmp" "$settings.new"
jq '.permissions.allow' "$dotclaude/settings.json" >|"$installed.new"

# キーと配列の並びをそろえてから比べる。並びだけの違いでは置き換えを勧めない
canonical='def canon: if type == "object" then to_entries | sort_by(.key) | map(.value |= canon) | from_entries elif type == "array" then map(canon) | sort_by(tojson) else . end; canon'
jq "$canonical" "$settings" >|"$settings.old.sorted"
jq "$canonical" "$settings.new" >|"$settings.new.sorted"

status=0
diff -u --label "$settings" --label "$settings.new" "$settings.old.sorted" "$settings.new.sorted" || status=$?
if [[ $status -eq 0 ]]; then
    rm "$settings.new"
    mv -f "$installed.new" "$installed"
    echo "OK settings.json は変わらない"
elif [[ $status -eq 1 ]]; then
    echo "確かめてから置き換える: mv \"$settings.new\" \"$settings\" && mv \"$installed.new\" \"$installed\""
else
    echo "NG diff が失敗した（終了コード ${status}）。$settings と $settings.new を確かめる"
    exit 1
fi
