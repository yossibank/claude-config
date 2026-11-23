#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"

tile="$root/dotclaude/skills/ui-record/scripts/tile-frames.sh"
record="$root/dotclaude/skills/ui-record/scripts/record-video.sh"

expect "NG 使い方" "tile-frames: 引数が足りなければ NG" bash "$tile" video.mp4 0 3 2 full 2
expect "NG 列数は 1 以上の整数にする" "tile-frames: 列数が整数でなければ NG" bash "$tile" video.mp4 0 3 2 full x "$work/out.png"
expect "NG 列数は 1 以上の整数にする" "tile-frames: 列数が 0 なら NG" bash "$tile" video.mp4 0 3 2 full 0 "$work/out.png"
expect "NG 開始の秒は 0 以上の数にする" "tile-frames: 開始の秒が数でなければ NG" bash "$tile" video.mp4 x 3 2 full 2 "$work/out.png"
expect "NG 長さの秒は 0 以上の数にする" "tile-frames: 長さの秒が数でなければ NG" bash "$tile" video.mp4 0 -1 2 full 2 "$work/out.png"
expect "NG 1 秒あたりのコマ数は 0 より大きい数にする" "tile-frames: コマ数が数でなければ NG" bash "$tile" video.mp4 0 3 x full 2 "$work/out.png"
expect "NG 1 秒あたりのコマ数は 0 より大きい数にする" "tile-frames: コマ数が 0 なら NG" bash "$tile" video.mp4 0 3 0 full 2 "$work/out.png"

fake_command ffmpeg "echo \"\$@\" >\"$work/ffmpeg.args\"; echo png >\"\${@: -1}\""
match "tile-frames: コマ数と列数を知らせる" "$(bash "$tile" video.mp4 1 2.5 2 full 3 "$work/out.png")" "OK $work/out.png（5 コマ、3 列）"
match "tile-frames: 行数をコマ数と列数から決める" "$(cat "$work/ffmpeg.args")" "*tile=3x2*"
match "tile-frames: 開始と長さを ffmpeg に渡す" "$(cat "$work/ffmpeg.args")" "*-ss 1 -t 2.5 -i video.mp4*"
match "tile-frames: full なら切り抜かない" "$(cat "$work/ffmpeg.args")" "*-vf fps=2,scale=320:-1*"
bash "$tile" video.mp4 0 1 2 100:200:0:50 1 "$work/out.png" >/dev/null
match "tile-frames: 切り抜きの指定を filter に入れる" "$(cat "$work/ffmpeg.args")" "*fps=2,crop=100:200:0:50,scale*tile=1x2*"
match "tile-frames: 長さが 0 でも 1 コマは出す" "$(bash "$tile" video.mp4 0 0 2 full 4 "$work/out.png")" "OK $work/out.png（1 コマ、4 列）"
fake_command ffmpeg 'exit 3'
expect "NG ffmpeg が失敗した（終了コード 3）" "tile-frames: ffmpeg が落ちたら NG の行を出す" bash "$tile" video.mp4 0 1 2 full 2 "$work/fail.png"
fake_command ffmpeg 'exit 0'
expect "NG 画像ができなかった: $work/none.png" "tile-frames: 何も書かずに終わったら NG" bash "$tile" video.mp4 0 1 2 full 2 "$work/none.png"

expect "NG 使い方" "record-video: 引数が足りなければ NG" bash "$record" udid 1
expect "NG 録画する秒数は 0 より大きい数にする" "record-video: 秒数が数でなければ NG" bash "$record" udid x "$work/rec/a.mp4"
expect "NG 録画する秒数は 0 より大きい数にする" "record-video: 秒数が 0 なら NG" bash "$record" udid 0 "$work/rec/a.mp4"
seconds=0.3
fake_command xcrun 'exit 1'
expect "NG 録画が始まらなかった: udid" "record-video: simctl がすぐ終われば NG" bash "$record" udid 1 "$work/rec/a.mp4"
fake_command xcrun "#!$(command -v python3)"'
import signal, sys, time
signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
open(sys.argv[-1], "w").write("v")
time.sleep(2)'
match "record-video: 出力先のフォルダを作って録る" "$(bash "$record" udid "$seconds" "$work/rec/b.mp4")" "OK $work/rec/b.mp4"
check "record-video: mp4 ができる" test -s "$work/rec/b.mp4"
fake_command xcrun "#!$(command -v python3)"'
import signal, sys, time
signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
time.sleep(2)'
expect "NG 録画できなかった: $work/rec/c.mp4" "record-video: ファイルが空なら NG" bash "$record" udid "$seconds" "$work/rec/c.mp4"

fake_command ffmpeg "echo \"\$@\" >\"$work/ffmpeg.args\"; echo png >\"\${@: -1}\""
bash "$tile" video.mp4 0 1 2 'min(100,200):50:0:0' 1 "$work/comma.png" >/dev/null
match "tile-frames: crop のカンマを filter の区切りにしない" "$(cat "$work/ffmpeg.args")" '*crop=min(100\\,200):50:0:0*'
fake_command xcrun 'echo "Invalid device" >&2; exit 1'
expect "Invalid device" "record-video: simctl の stderr の最後の行を NG に入れる" bash "$record" udid 5 "$work/rec/d.mp4"

ready="$root/dotclaude/skills/ui-record/scripts/wait-simulator.sh"
expect "NG 使い方" "wait-simulator: 引数が無ければ NG" bash "$ready"
expect "NG 待つ秒数は 1 以上の整数にする" "wait-simulator: 待つ秒数が整数でなければ NG" bash "$ready" udid x
fake_command xcrun 'exit 0'
fake_command axe "n=\$(cat '$work/axe.count' 2>/dev/null || echo 0); echo \$((n + 1)) >'$work/axe.count'; [[ \$1 == describe-ui && \$n -ge 1 ]] && exit 0; echo 'Error: Timed out creating the simulator remote automation session' >&2; exit 1"
match "wait-simulator: 最初の読み取りが失敗しても、通るまでやり直す" "$(bash "$ready" udid 10)" "OK udid*"
match "wait-simulator: 2 回目で通る" "$(cat "$work/axe.count")" "2"
fake_command axe "echo 'Error: Timed out creating the simulator remote automation session' >&2; exit 1"
expect "Timed out creating the simulator remote automation session" "wait-simulator: 待っても読めなければ、axe の最後の行を NG に入れる" bash "$ready" udid 1
fake_command xcrun '[[ $2 == bootstatus ]] && exit 1; exit 0'
expect "NG 起動を待てなかった" "wait-simulator: 起動を待てなければ NG" bash "$ready" udid 5

finish
