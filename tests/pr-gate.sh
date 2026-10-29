#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hooks.sh"

push() {
    echo "{\"cwd\":\"$1\",\"tool_input\":{\"command\":\"$2\"}}"
}

run pr-gate 2 "pr: 確認の記録が無いと push を止める" "$(push "$app" 'git push -u origin feat/x')"
"$check" "$app" "true" true >/dev/null
run pr-gate 0 "pr: 確認を通せば push を通す" "$(push "$app" 'git push -u origin feat/x')"
run pr-gate 0 "pr: 確認を通せば gh pr create を通す" "$(push "$app" 'gh pr create --title x')"
echo 'struct B {}' >>"$swift"
run pr-gate 2 "pr: 確認の後に変えると止める" "$(push "$app" 'git push')"
"$check" "$app" "true" true >/dev/null
"$check" "$app" "false" false >/dev/null
run pr-gate 2 "pr: NG の確認が残ると止める" "$(push "$app" 'git push')"
"$check" "$app" --drop "false" >/dev/null
run pr-gate 0 "pr: --drop で外せば通す" "$(push "$app" 'git push')"
echo 'struct C {}' >>"$swift"
run pr-gate 0 "pr: タグの push は止めない" "$(push "$app" 'git push --tags')"
run pr-gate 0 "pr: ブランチの削除は止めない" "$(push "$app" 'git push origin --delete feat/x')"
run pr-gate 0 "pr: : で始まる refspec の削除は止めない" "$(push "$app" 'git push origin :feat/x')"
run pr-gate 2 "pr: draft の PR（gh pr create -d）も止める" "$(push "$app" 'gh pr create -d --title x')"
run pr-gate 2 "pr: 別のコマンドの -d に引きずられない" "$(push "$app" 'git branch -d old && git push')"
run pr-gate 2 "pr: git -C で別のリポジトリを指しても、そのリポジトリを見る" "$(push "$work" "git -C $app push")"
run pr-gate 0 "pr: 関係ないコマンドは止めない" "$(push "$app" 'git status')"
run pr-gate 2 "pr: cd した先のリポジトリを見る" "$(push "$work" "cd $app && git push")"
run pr-gate 2 "pr: 題の引用符の中の ; で区切らずに止める" "$(push "$app" 'gh pr create --title \"fix; typo\"')"
run pr-gate 2 "pr: 本文の引用符の中の | で区切らずに止める" "$(push "$app" 'gh pr create --body \"a | b\"')"
run pr-gate 2 "pr: 閉じていない引用符でも止める" "$(push "$app" 'gh pr create --title \"x')"
run pr-gate 2 "pr: 語の中の # をコメントと見なさずに止める" "$(push "$app" 'curl http://x/#a && git push')"
run pr-gate 2 "pr: 閉じていない引用符でも、区切りの後の push を止める" "$(push "$app" "echo it's&&git push")"
run pr-gate 2 "pr: 改行で並べたコマンドも区切って止める" "$(push "$work" "cd $app\\ngit push")"
run pr-gate 0 "pr: 引用符の中の gh pr create は止めない" "$(push "$app" 'echo \"gh pr create\"')"
CC_HOOKS_OFF="rules-require-read pr-gate" run pr-gate 0 "pr: CC_HOOKS_OFF に名前があれば止めない" "$(push "$app" 'git push')"
CC_HOOKS_OFF="pr-gate-x" run pr-gate 2 "pr: CC_HOOKS_OFF の名前は全体で比べる" "$(push "$app" 'git push')"
printf '#!/bin/bash\necho "壊れた" >&2\nexit 3\n' >"$work/broken-check.sh"
out=$(python3 -I - "$root" "$work/broken-check.sh" "$app" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1] + "/lib")
from loader import load_hook
gate = load_hook("pr-gate")
gate.CHECK_SH = sys.argv[2]
print(gate.problems(sys.argv[3]))
EOF
)
check "pr: run-check.sh が何も出さずに落ちたら、理由に stderr の末尾を出す" grep -q "run-check.sh が失敗した（終了コード 3）: 壊れた" <<<"$out"
out=$(python3 -I - "$root" "$app" 2>&1 <<'EOF'
import subprocess, sys
sys.path.insert(0, sys.argv[1] + "/lib")
from loader import load_hook
gate = load_hook("pr-gate")
gate.git_root = lambda repo: repo


def slow(*args, **kwargs):
    raise subprocess.TimeoutExpired(args[0], 30)


gate.subprocess.run = slow
print(gate.problems(sys.argv[2]))
EOF
)
check "pr: run-check.sh が時間切れなら、stderr に知らせて通す" grep -q "確かめずに通す（TimeoutExpired）" <<<"$out"
CC_HOOKS_OFF="rules-require-read,pr-gate" run pr-gate 0 "pr: CC_HOOKS_OFF はカンマで区切ってもよい" "$(push "$app" 'git push')"
CC_HOOKS_OFF=$'rules-require-read\tpr-gate' run pr-gate 0 "pr: CC_HOOKS_OFF はタブで区切ってもよい" "$(push "$app" 'git push')"
out=$(push "$app" 'git status' | CC_HOOKS_OFF="pr-gate.py" bash "$hooks" pr-gate 2>&1)
check "pr: CC_HOOKS_OFF に hooks/ に無い名前があれば警告する" grep -q "hooks/ に無い名前がある: pr-gate.py" <<<"$out"
out=$(push "$app" 'git status' | CC_HOOKS_OFF="" bash "$hooks" pr-gate 2>&1)
check "pr: CC_HOOKS_OFF が空なら何も出さない" test -z "$out"

finish
