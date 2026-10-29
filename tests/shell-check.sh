#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/fixtures.sh"
source "$(dirname "$0")/lib/hooks.sh"

printf '#!/bin/bash\necho "x $name%s"\n' '。' >"$work/wide.sh"
printf '#!/bin/bash\necho "x ${name}。"\n' >"$work/ok.sh"
run shell-check 2 "shell: 変数の直後の全角で止まる" "{\"tool_input\":{\"file_path\":\"$work/wide.sh\"}}"
run shell-check 0 "shell: \${名前} で囲めば通る" "{\"tool_input\":{\"file_path\":\"$work/ok.sh\"}}"
printf '#!/bin/bash\nif true; then\n' >"$work/broken.sh"
run shell-check 2 "shell: bash -n が通らなければ止まる" "{\"tool_input\":{\"file_path\":\"$work/broken.sh\"}}"

finish
