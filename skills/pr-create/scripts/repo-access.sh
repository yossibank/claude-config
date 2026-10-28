#!/bin/bash
set -euo pipefail

[[ $# -ge 1 ]] || { echo "NG 使い方: $(basename "$0") <リポジトリのパス>"; exit 1; }

info=$(cd "$1" && gh repo view --json owner,name,viewerPermission \
    -q '"\(.owner.login) \(.name) \(.viewerPermission)"') || { echo "NG gh repo view が通らない"; exit 1; }
read -r owner name permission <<< "$info"

case $permission in
    ADMIN | MAINTAIN | WRITE) echo "$owner $name write" ;;
    *) echo "$owner $name read" ;;
esac
