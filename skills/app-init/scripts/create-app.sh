#!/bin/bash
set -euo pipefail

[[ $# -ge 2 ]] || { echo "NG 使い方: $(basename "$0") <アプリの名前（英小文字）> <ストアの表示名>"; exit 1; }

skill=$(cd "$(dirname "$0")/.." && pwd -P)
name="$1"
display="$2"
root="${CC_APPS_DIR:-$HOME/Applications/AppStore}/$name"

[[ "$name" =~ ^[a-z][a-z0-9]*$ ]] || { echo "NG 名前は英小文字と数字だけにする: $name"; exit 1; }
case "$name" in
    app | core | store | features | appfeature | designsystem) echo "NG パッケージのモジュールと同じ名前は使えない: $name"; exit 1 ;;
esac
[[ "$display" == *[\"\\]* || "$display" == *$'\n'* ]] && { echo "NG 表示名に \" や \\ や改行は使えない"; exit 1; }

pascal="$(tr '[:lower:]' '[:upper:]' <<<"${name:0:1}")${name:1}"

if [[ -d $root ]]; then
    others=$(find "$root" -mindepth 1 -maxdepth 1 ! -name docs ! -name .DS_Store | head -1)
    [[ -z $others ]] || { echo "NG docs/ のほかに中身がある: $root"; exit 1; }
fi

[[ -d $root ]] && fresh="" || fresh=1
copied=()

cleanup() {
    if [[ -n $fresh ]]; then
        rm -rf "$root"
    else
        find "$root" -mindepth 1 -maxdepth 1 ! -name docs -exec rm -rf {} +
        for doc in "${copied[@]+"${copied[@]}"}"; do
            rm -f "$doc"
        done
    fi
    echo "NG 途中で止まったので、作りかけを消した: $root"
}

trap cleanup ERR

mkdir -p "$root/docs"
rsync -a --exclude .DS_Store --exclude /docs/ "$skill/templates/ios-app/" "$root/"

for doc in overview roadmap; do
    if [[ ! -f $root/docs/$doc.md ]]; then
        cp "$skill/templates/ios-app/docs/$doc.md" "$root/docs/$doc.md"
        copied+=("$root/docs/$doc.md")
    fi
done

python3 -I "$skill/scripts/replace-placeholders.py" "$root" "$pascal" "$name" "$display"

git -C "$root" init -q -b main
git -C "$root" add -A
git -C "$root" commit -q -m "chore: start $name from the ios-app template"

trap - ERR
echo "OK $root"
