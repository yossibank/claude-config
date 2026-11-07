#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hook_fixtures.sh"
STOP="シェルスクリプトに直すところがある"

printf '#!/bin/bash\necho "x $name%s"\n' '。' >"$work/wide.sh"
printf '#!/bin/bash\necho "x ${name}。"\n' >"$work/ok.sh"
run shell-check 2 "shell: 変数の直後の全角で止まる" "{\"tool_input\":{\"file_path\":\"$work/wide.sh\"}}"
run shell-check 0 "shell: \${名前} で囲めば通る" "{\"tool_input\":{\"file_path\":\"$work/ok.sh\"}}"
printf '#!/bin/bash\nif true; then\n' >"$work/broken.sh"
run shell-check 2 "shell: bash -n が通らなければ止まる" "{\"tool_input\":{\"file_path\":\"$work/broken.sh\"}}"

cp "$work/wide.sh" "$work/wide.txt"
run shell-check 0 "shell: 対象外の拡張子は見ない" "{\"tool_input\":{\"file_path\":\"$work/wide.txt\"}}"
run shell-check 0 "shell: 無いファイルは通す" "{\"tool_input\":{\"file_path\":\"$work/none.sh\"}}"

printf '#!/bin/bash\n# %s%s\necho ok\n' '$HOME' '用の説明' >"$work/comment.sh"
run shell-check 0 "shell: 注釈の行の変数の直後の全角は指摘しない" "{\"tool_input\":{\"file_path\":\"$work/comment.sh\"}}"
out=$(python3 -I - "$root" "$work/ok.sh" 2>&1 <<'EOF'
import subprocess, sys
import os
exec(os.environ["PY_PRELUDE"])
hook = load_hook("shell-check")


def slow(*args, **kwargs):
    raise subprocess.TimeoutExpired(args[0], 10)


hook.subprocess.run = slow
print(hook.check(sys.argv[2]))
EOF
)
check "shell: bash -n が時間切れなら、指摘として返す" grep -qF "bash -n を走らせられなかった（TimeoutExpired）" <<<"$out"

finish
