#!/bin/bash
set -euo pipefail

skill=$(cd "$(dirname "$0")/.." && pwd -P)
config=$(cd "$skill/../.." && pwd)
name="${1:?アプリの名前（英小文字）}"
display="${2:?ストアの表示名}"
root="${APPS_DIR:-$HOME/Applications/AppStore}/$name"

[[ "$name" =~ ^[a-z][a-z0-9]*$ ]] || { echo "NG 名前は英小文字と数字だけにする: $name"; exit 1; }
case "$name" in
    app | core | store | features | appfeature | designsystem) echo "NG パッケージのモジュールと同じ名前は使えない: $name"; exit 1 ;;
esac
[[ "$display" == *[\"\\]* || "$display" == *$'\n'* ]] && { echo "NG 表示名に \" や \\ や改行は使えない"; exit 1; }

pascal="$(tr '[:lower:]' '[:upper:]' <<<"${name:0:1}")${name:1}"

if [ -d "$root" ]; then
    others=$(find "$root" -mindepth 1 -maxdepth 1 ! -name docs ! -name .DS_Store | head -1)
    [ -z "$others" ] || { echo "NG docs/ のほかに中身がある: $root"; exit 1; }
fi

mkdir -p "$root/docs"
rsync -a --exclude .DS_Store "$config/templates/ios-app/" "$root/"

for doc in overview roadmap; do
    [ -f "$root/docs/$doc.md" ] || cp "$config/skills/app-plan/templates/$doc.md" "$root/docs/$doc.md"
done

python3 -I "$skill/scripts/rename.py" "$root" "$pascal" "$name" "$display"

git -C "$root" init -q -b main
git -C "$root" add -A
git -C "$root" commit -q -m "chore: start $name from the ios-app template"

echo "OK $root"
