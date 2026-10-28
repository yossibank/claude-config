#!/bin/bash
set -euo pipefail

device="${1:?シミュレーターの UDID}"
seconds="${2:?録画する秒数}"
out="${3:?出力する mp4}"

mkdir -p "$(dirname "$out")"
xcrun simctl io "$device" recordVideo --codec h264 --force "$out" >/dev/null 2>&1 &
pid=$!
sleep "$seconds"
kill -0 "$pid" 2>/dev/null || { echo "NG 録画が始まらなかった: $device"; exit 1; }
kill -INT "$pid"
wait "$pid" || true
sleep 1

[ -s "$out" ] || { echo "NG 録画できなかった: $out"; exit 1; }
echo "OK $out"
