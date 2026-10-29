#!/bin/bash
set -euo pipefail

[[ $# -ge 3 ]] || { echo "NG 使い方: $(basename "$0") <シミュレーターの UDID> <録画する秒数> <出力する mp4>"; exit 1; }

device="$1"
seconds="$2"
out="$3"

mkdir -p "$(dirname "$out")"
xcrun simctl io "$device" recordVideo --codec h264 --force "$out" >/dev/null 2>&1 &
pid=$!
sleep "$seconds"
kill -0 "$pid" 2>/dev/null || { echo "NG 録画が始まらなかった: $device"; exit 1; }
kill -INT "$pid"
wait "$pid" || true
sleep 1

[[ -s $out ]] || { echo "NG 録画できなかった: $out"; exit 1; }
echo "OK $out"
