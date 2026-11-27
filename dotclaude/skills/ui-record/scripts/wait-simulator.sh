#!/bin/bash
set -euo pipefail

[[ $# -ge 1 ]] || { echo "NG 使い方: $(basename "$0") <シミュレーターの UDID> [待つ秒数]"; exit 1; }

device="$1"
limit="${2:-120}"
[[ $limit =~ ^[1-9][0-9]*$ ]] || { echo "NG 待つ秒数は 1 以上の整数にする: $limit"; exit 1; }
command -v axe >/dev/null || { echo "NG axe が無い。brew install cameroncooke/axe/axe で入れる"; exit 1; }

xcrun simctl boot "$device" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device" >/dev/null 2>&1 || { echo "NG 起動を待てなかった: $device"; exit 1; }

start=$SECONDS
last=""
while ((SECONDS - start < limit)); do
    if last=$(axe describe-ui --udid "$device" 2>&1 >/dev/null); then
        echo "OK ${device}（$((SECONDS - start)) 秒で画面を読めた）"
        exit 0
    fi
    sleep 2
done
echo "NG ${limit} 秒たっても画面を読めない: ${device}（${last##*$'\n'}）"
exit 1
