#!/bin/bash
set -euo pipefail

[[ $# -ge 7 ]] || { echo "NG 使い方: $(basename "$0") <録画した mp4> <開始の秒> <長さの秒> <1 秒あたりのコマ数> <crop か full> <列数> <出力する png>"; exit 1; }

video="$1"
start="$2"
duration="$3"
fps="$4"
crop="$5"
columns="$6"
[[ $columns =~ ^[1-9][0-9]*$ ]] || { echo "NG 列数は 1 以上の整数にする: $columns"; exit 1; }
out="$7"

count=$(awk -v d="$duration" -v f="$fps" 'BEGIN { n = int(d * f + 0.999); print (n < 1 ? 1 : n) }')
rows=$(( (count + columns - 1) / columns ))
filter="fps=$fps"

if [ "$crop" != "full" ]; then
    filter="$filter,crop=$crop"
fi

ffmpeg -loglevel error -y -ss "$start" -t "$duration" -i "$video" \
    -vf "$filter,scale=320:-1,tile=${columns}x${rows}" -frames:v 1 "$out"

echo "OK $out (${count} コマ、${columns} 列)"
