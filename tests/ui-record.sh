#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"

tile="$root/skills/ui-record/scripts/tile-frames.sh"
record="$root/skills/ui-record/scripts/record-video.sh"

expect "NG 使い方" "tile-frames: 引数が足りなければ NG" bash "$tile" video.mp4 0 3 2 full 2
expect "NG 列数は 1 以上の整数にする" "tile-frames: 列数が整数でなければ NG" bash "$tile" video.mp4 0 3 2 full x "$work/out.png"
expect "NG 列数は 1 以上の整数にする" "tile-frames: 列数が 0 なら NG" bash "$tile" video.mp4 0 3 2 full 0 "$work/out.png"
expect "NG 開始の秒は 0 以上の数にする" "tile-frames: 開始の秒が数でなければ NG" bash "$tile" video.mp4 x 3 2 full 2 "$work/out.png"
expect "NG 長さの秒は 0 以上の数にする" "tile-frames: 長さの秒が数でなければ NG" bash "$tile" video.mp4 0 -1 2 full 2 "$work/out.png"
expect "NG 1 秒あたりのコマ数は 0 より大きい数にする" "tile-frames: コマ数が数でなければ NG" bash "$tile" video.mp4 0 3 x full 2 "$work/out.png"
expect "NG 1 秒あたりのコマ数は 0 より大きい数にする" "tile-frames: コマ数が 0 なら NG" bash "$tile" video.mp4 0 3 0 full 2 "$work/out.png"

fake_command ffmpeg "echo \"\$@\" >\"$work/ffmpeg.args\""
match "tile-frames: コマ数と列数を知らせる" "$(bash "$tile" video.mp4 1 2.5 2 full 3 "$work/out.png")" "OK $work/out.png（5 コマ、3 列）"
match "tile-frames: 行数をコマ数と列数から決める" "$(cat "$work/ffmpeg.args")" "*tile=3x2*"
match "tile-frames: 開始と長さを ffmpeg に渡す" "$(cat "$work/ffmpeg.args")" "*-ss 1 -t 2.5 -i video.mp4*"
match "tile-frames: full なら切り抜かない" "$(cat "$work/ffmpeg.args")" "*-vf fps=2,scale=320:-1*"
bash "$tile" video.mp4 0 1 2 100:200:0:50 1 "$work/out.png" >/dev/null
match "tile-frames: 切り抜きの指定を filter に入れる" "$(cat "$work/ffmpeg.args")" "*fps=2,crop=100:200:0:50,scale*tile=1x2*"
match "tile-frames: 長さが 0 でも 1 コマは出す" "$(bash "$tile" video.mp4 0 0 2 full 4 "$work/out.png")" "OK $work/out.png（1 コマ、4 列）"

expect "NG 使い方" "record-video: 引数が足りなければ NG" bash "$record" udid 1
expect "NG 録画する秒数は 0 より大きい数にする" "record-video: 秒数が数でなければ NG" bash "$record" udid x "$work/rec/a.mp4"
expect "NG 録画する秒数は 0 より大きい数にする" "record-video: 秒数が 0 なら NG" bash "$record" udid 0 "$work/rec/a.mp4"
fake_command xcrun 'exit 1'
expect "NG 録画が始まらなかった: udid" "record-video: simctl がすぐ終われば NG" bash "$record" udid 1 "$work/rec/a.mp4"
fake_command xcrun '#!/usr/bin/env python3
import signal, sys, time
signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
open(sys.argv[-1], "w").write("v")
time.sleep(3)'
match "record-video: 出力先のフォルダを作って録る" "$(bash "$record" udid 1 "$work/rec/b.mp4")" "OK $work/rec/b.mp4"
check "record-video: mp4 ができる" test -s "$work/rec/b.mp4"
fake_command xcrun '#!/usr/bin/env python3
import signal, sys, time
signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
time.sleep(3)'
expect "NG 録画できなかった: $work/rec/c.mp4" "record-video: ファイルが空なら NG" bash "$record" udid 1 "$work/rec/c.mp4"

finish
