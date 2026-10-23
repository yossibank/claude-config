#!/bin/bash
set -euo pipefail

video="${1:?録画した mp4}"
start="${2:?開始の秒}"
duration="${3:?長さの秒}"
fps="${4:?1 秒あたりのコマ数}"
crop="${5:?crop か full}"
columns="${6:?列数}"
out="${7:?出力する png}"

count=$(awk -v d="$duration" -v f="$fps" 'BEGIN { n = int(d * f + 0.999); print (n < 1 ? 1 : n) }')
rows=$(( (count + columns - 1) / columns ))
filter="fps=$fps"

if [ "$crop" != "full" ]; then
    filter="$filter,crop=$crop"
fi

ffmpeg -loglevel error -y -ss "$start" -t "$duration" -i "$video" \
    -vf "$filter,scale=320:-1,tile=${columns}x${rows}" -frames:v 1 "$out"

echo "OK $out (${count} コマ、${columns} 列)"
