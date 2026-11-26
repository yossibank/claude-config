#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$root/tests/support/fixtures.sh"

script="$root/bin/pr-merge.sh"
calls="$work/calls"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

fake_gh "case \"\$1 \$2\" in
    'repo view') echo o/r ;;
    'pr list')
        while [[ \$# -gt 0 && \$1 != --jq ]]; do shift; done
        jq -r \"\$2\" \"$work/prs.json\" ;;
    'pr view')
        if git -C \"$work/r.git\" merge-base --is-ancestor main \"\$(cat \"$work/head-\$3\")\"; then echo MERGEABLE; else echo CONFLICTING; fi ;;
    'pr merge')
        [[ -f \"$work/refuse\" ]] && exit 1
        git -C \"$work/r.git\" merge-base --is-ancestor main \"\$(cat \"$work/head-\$3\")\" || exit 1
        echo \"merge \$3\" >>\"$calls\" ;;
    'pr comment') echo \"comment \$3\" >>\"$calls\" ;;
    'pr edit') echo \"edit \$3 \$6\" >>\"$calls\" ;;
    'label create') echo \"label \$3\" >>\"$calls\" ;;
esac"
fake_command claude "echo claude >>\"$calls\"
case \$2 in
    *確認が落ちた*)
        [[ -f \"$work/claude-fix\" ]] && touch fixed
        echo OK ;;
    *)
        if [[ -f \"$work/claude-ng\" ]]; then echo 'NG 決まらない'; exit 0; fi
        git diff --name-only --diff-filter=U | while read -r file; do printf 'b\nc\n' >\"\$file\"; done
        echo OK ;;
esac"
fake_command make "echo \"make \$1\" >>\"$calls\"
touch build.out
[[ \$1 == verify && -f \"$work/verify-fail\" && ! -f fixed ]] && { echo 'error: broken'; exit 1; }
exit 0"
fake_command terminal-notifier "echo \"notify \$2\" >>\"$calls\""
fake_command pgrep "[[ -f \"$work/xcodebuild\" ]]"
fake_command sleep "exit 0"
fake_command launchctl "echo \"launchctl \$1\" >>\"$calls\""

setup() {
    rm -rf "$work/r" "$work/r.git" "$work/home" "$work"/head-* "$work"/claude-* "$work/verify-fail" "$work/xcodebuild" "$work/refuse"
    : >"$calls"
    export HOME="$work/home"
    mkdir -p "$HOME"
    clone_with_origin "$work/r"
    printf 'verify:\n\ttrue\ntest:\n\ttrue\n' >"$work/r/Makefile"
    commit "$work/r" make
    git -C "$work/r" push -q origin main
    git -C "$work/r" switch -q -c feature
    echo b >"$work/r/a.md"
    commit "$work/r" feature
    git -C "$work/r" push -q origin feature
    git -C "$work/r" switch -q main
    echo c >"$work/r/a.md"
    commit "$work/r" main
    git -C "$work/r" push -q origin main
    git -C "$work/r" switch -q -c clean
    echo x >"$work/r/b.md"
    commit "$work/r" clean
    git -C "$work/r" push -q origin clean
    git -C "$work/r" switch -q main
    echo feature >"$work/head-1"
    echo clean >"$work/head-2"
    echo clean >"$work/head-3"
    jq -n --arg f "$(git -C "$work/r" rev-parse feature)" --arg c "$(git -C "$work/r" rev-parse clean)" '[
        {number: 3, isDraft: true, headRefName: "clean", headRefOid: $c, url: "u3", title: "draft"},
        {number: 2, isDraft: false, headRefName: "clean", headRefOid: $c, url: "u2", title: "clean"},
        {number: 1, isDraft: false, headRefName: "feature", headRefOid: $f, url: "u1", title: "feature"}
    ]' >"$work/prs.json"
}

expect "NG 使い方" "pr-merge: 引数が無ければ NG" bash "$script"
expect "NG 使い方" "pr-merge: 知らない指示は NG" bash "$script" stop "$work"

setup
out=$(bash "$script" run "$work/r" 2>&1)
match "pr-merge: 競合の無い PR をマージする" "$out" "*OK o/r#2 マージした*"
check "pr-merge: 下書きの PR はマージしない" test -z "$(grep -x 'merge 3' "$calls")"
match "pr-merge: 競合を解いて push してからマージする" "$out" "*OK o/r#1 競合を解いてマージした*"
match "pr-merge: 解いた中身を PR のブランチに push する" "$(git -C "$work/r.git" show feature:a.md)" $'b\nc'
check "pr-merge: 番号の小さい PR から先に回す" test "$(grep '^merge' "$calls" | head -1)" = "merge 1"
check "pr-merge: verify に test が無ければ test も通す" grep -qx 'make test' "$calls"
check "pr-merge: 競合を解いてマージしたら通知する" grep -qx 'notify 競合を解いてマージしました' "$calls"

setup
printf 'verify: audit test\n\ttrue\naudit:\n\ttrue\ntest:\n\ttrue\n' >"$work/r/Makefile"
commit "$work/r" make
git -C "$work/r" push -q origin main
bash "$script" run "$work/r" >/dev/null 2>&1
check "pr-merge: verify が test を含めば test を重ねない" test -z "$(grep -x 'make test' "$calls")"

setup
touch "$work/verify-fail" "$work/claude-fix"
out=$(bash "$script" run "$work/r" 2>&1)
match "pr-merge: 落ちた確認を 1 回だけ直させて通す" "$out" "*OK o/r#1 競合を解いてマージした*"
match "pr-merge: 直した所は別の commit にする" "$(git -C "$work/r.git" log -1 --format=%s feature)" "fix: keep the checks passing after the rebase onto main"
check "pr-merge: 確認が作ったファイルは直しの commit に入れない" test -z "$(git -C "$work/r.git" ls-tree --name-only feature build.out)"

setup
touch "$work/refuse"
bash "$script" run "$work/r" >/dev/null 2>&1
: >"$calls"
out=$(bash "$script" run "$work/r" 2>&1)
match "pr-merge: 断られたままの PR は次の回に止め直さない" "$out" "*SKIP o/r#2 前の回に止めたままの中身*"
check "pr-merge: 止め直さない回はコメントしない" test -z "$(grep '^comment' "$calls")"

setup
rm -rf "$work/r.git"
: >"$calls"
out=$(bash "$script" run "$work/r" 2>&1)
match "pr-merge: origin から取れないリポジトリは回さない" "$out" "*NG $work/r を回せなかった*"
check "pr-merge: 回さないリポジトリの PR には触らない" test ! -s "$calls"

setup
touch "$work/verify-fail"
out=$(bash "$script" run "$work/r" 2>&1)
match "pr-merge: 直しても確認が落ちたら止める" "$out" "*NG o/r#1 競合を解いた後の確認が落ちました*"
check "pr-merge: 止めたら push しない" test "$(git -C "$work/r.git" show feature:a.md)" = b
check "pr-merge: 止めたら PR にコメントする" grep -qx 'comment 1' "$calls"
check "pr-merge: 止めたら通知する" grep -qx 'notify 自動マージを止めました' "$calls"
check "pr-merge: 止めたらラベルを作って付ける" grep -qx 'label auto-merge-stopped' "$calls"
check "pr-merge: 止めた PR にラベルを付ける" grep -qx 'edit 1 --add-label' "$calls"
: >"$calls"
out=$(bash "$script" run "$work/r" 2>&1)
match "pr-merge: 止めたままの中身は次の回に解き直さない" "$out" "*SKIP o/r#1 前の回に止めたままの中身*"
check "pr-merge: 解き直さない回は claude を呼ばない" test -z "$(grep -x claude "$calls")"
echo y >"$work/r/c.md"
commit "$work/r" base
git -C "$work/r" push -q origin main
rm "$work/verify-fail"
: >"$calls"
out=$(bash "$script" run "$work/r" 2>&1)
match "pr-merge: main が進んだら止めた PR を解き直す" "$out" "*OK o/r#1 競合を解いてマージした*"
check "pr-merge: 止めた PR をマージしたらラベルを外す" grep -qx 'edit 1 --remove-label' "$calls"

setup
touch "$work/claude-ng"
out=$(bash "$script" run "$work/r" 2>&1)
match "pr-merge: 解けない競合は理由を付けて止める" "$out" "*NG o/r#1 競合を解けませんでした（決まらない）*"
check "pr-merge: 解けない時はワークツリーの載せ直しを戻す" test ! -d "$(git -C "$HOME/.claude/worktrees/r-pr-merge" rev-parse --git-path rebase-merge)"

setup
touch "$work/xcodebuild"
out=$(bash "$script" run "$work/r" 2>&1)
match "pr-merge: xcodebuild が動いている時は次の回に回す" "$out" "*SKIP o/r#1 xcodebuild が動いている*"
check "pr-merge: 回さない時は claude を呼ばない" test -z "$(grep -x claude "$calls")"

setup
mkdir -p "$HOME/.claude/state/pr-merge/lock"
out=$(bash "$script" run "$work/r" 2>&1)
match "pr-merge: 前の回が動いている時は回さない" "$out" "SKIP 前の回がまだ動いている"

setup
out=$(bash "$script" install "$work/r" 2>&1)
plist="$HOME/Library/LaunchAgents/com.claude-config.pr-merge.plist"
match "pr-merge: launchd の plist を入れる" "$out" "OK *を入れた"
check "pr-merge: plist の形が正しい" plutil -lint "$plist"
check "pr-merge: plist に回すリポジトリを書く" grep -qF "<string>$(cd "$work/r" && pwd -P)</string>" "$plist"
check "pr-merge: launchd に読み込ませる" grep -qx 'launchctl bootstrap' "$calls"
expect "NG Git のリポジトリではない" "pr-merge: リポジトリでない場所は入れない" bash "$script" install "$work/nothing"

finish
