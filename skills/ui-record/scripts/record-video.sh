#!/bin/bash
set -euo pipefail

[[ $# -ge 3 ]] || { echo "NG 使い方: $(basename "$0") <シミュレーターの UDID> <録画する秒数> <出力する mp4>"; exit 1; }

device="$1"
seconds="$2"
[[ $seconds =~ ^[0-9]+([.][0-9]+)?$ && ! $seconds =~ ^0+([.]0+)?$ ]] || { echo "NG 録画する秒数は 0 より大きい数にする: $seconds"; exit 1; }
out="$3"

mkdir -p "$(dirname "$out")"
log="$out.log"
xcrun simctl io "$device" recordVideo --codec h264 --force "$out" >/dev/null 2>"$log" &
pid=$!
trap 'kill -INT "$pid" 2>/dev/null || true' EXIT
first=$(awk -v s="$seconds" 'BEGIN { print (s < 1 ? s : 1) }')
sleep "$first"
kill -0 "$pid" 2>/dev/null || { echo "NG 録画が始まらなかった: ${device}（$(tail -n 1 "$log")。ログ: ${log}）"; exit 1; }
sleep "$(awk -v s="$seconds" -v f="$first" 'BEGIN { print s - f }')"
kill -INT "$pid"
wait "$pid" || true
trap - EXIT
sleep 1

[[ -s $out ]] || { echo "NG 録画できなかった: ${out}（$(tail -n 1 "$log")。ログ: ${log}）"; exit 1; }
rm -f "$log"
echo "OK $out"
