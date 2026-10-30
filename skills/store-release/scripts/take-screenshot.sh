#!/bin/bash
set -euo pipefail

[[ $# -ge 2 ]] || { echo "NG 使い方: $(basename "$0") <シミュレーターの UDID> <出力する PNG>"; exit 1; }

device="$1"
out="$2"

xcrun simctl bootstatus "$device" -b >/dev/null || { echo "NG シミュレーターが起動しない: $device"; exit 1; }
xcrun simctl status_bar "$device" override \
    --time "9:41" \
    --dataNetwork wifi \
    --wifiMode active \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100 || { echo "NG ステータスバーを固定できない: $device"; exit 1; }
mkdir -p "$(dirname "$out")"
xcrun simctl io "$device" screenshot --type png "$out" >/dev/null 2>&1 || { echo "NG スクリーンショットを撮れない: $device"; exit 1; }

size=$(sips -g pixelWidth -g pixelHeight "$out" | awk '/pixel/ { print $2 }' | paste -sd x -) || { echo "NG 画像の大きさを読めない: $out"; exit 1; }
case "$size" in
    1320x2868 | 1290x2796 | 1260x2736) echo "OK $out ($size)" ;;
    *) echo "NG $out ($size)。6.9 インチの大きさではない"; exit 1 ;;
esac
