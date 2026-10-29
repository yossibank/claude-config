#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/lib/assert.sh"

export HOME="$work/home"
config="$HOME/Applications/AI/claude-config"
claude="$HOME/.claude"
settings="$claude/settings.json"

mkdir -p "$config" "$claude/skills"
(cd "$root" && git ls-files -z | rsync -a --from0 --files-from=- ./ "$config/")

cat >"$settings" <<'JSON'
{
  "permissions": {"allow": ["Bash(ls *)", "Bash(retired *)"]},
  "outputStyle": "mine",
  "hooks": {
    "Stop": [{"hooks": [
      {"type": "command", "command": "python3 \"$HOME/Applications/AI/claude-config/hooks/old.py\""},
      {"type": "command", "command": "echo mine"}
    ]}]
  }
}
JSON
ln -s "$work/nowhere" "$claude/skills/gone"
echo '["Bash(retired *)"]' >"$claude/claude-config-allow.json"

out=$(bash "$config/scripts/config-install.sh" 2>&1)
check "install: CLAUDE.md をリンクする" test -L "$claude/CLAUDE.md"
check "install: スキルをリンクする" test -L "$claude/skills/pr-create"
check "install: 壊れたスキルのリンクを消す" test ! -L "$claude/skills/gone"
check "install: settings.json は直接書き換えない" grep -q 'old.py' "$settings"
check "install: 置き換えの案を出す" test -f "$settings.new"
check "merge: ほかのフックを残す" jq -e '[.hooks.Stop[].hooks[].command] | index("echo mine")' "$settings.new"
check "merge: 古い claude-config のフックを外す" jq -e '[.. | .command? // empty] | map(select(contains("old.py"))) | length == 0' "$settings.new"
check "merge: 今のフックを run.sh で入れる" jq -e '[.. | .command? // empty] | map(select(contains("hooks/run.sh"))) | length > 0' "$settings.new"
check "install: output style をリンクする" test -L "$claude/output-styles/report.md"
check "merge: 自分で決めた outputStyle を残す" jq -e '.outputStyle == "mine"' "$settings.new"
echo '{}' >"$work/own.json"
check "merge: 無い outputStyle を入れる" jq -e '.outputStyle == "report"' <(jq -s -f "$config/settings/merge.jq" "$work/own.json" "$config/settings/settings.json" <(echo '[]'))
check "merge: 今の許可を前に残す" jq -e '.permissions.allow[0] == "Bash(ls *)"' "$settings.new"
check "merge: claude-config から消えた許可を外す" jq -e '.permissions.allow | index("Bash(retired *)") | not' "$settings.new"
check "install: 入れた許可の一覧は、置き換えるまで前のものを残す" jq -e 'index("Bash(retired *)")' "$claude/claude-config-allow.json"
check "install: 入れた許可の一覧の案を出す" jq -e 'index("Bash(make verify)")' "$claude/claude-config-allow.json.new"
expect OK "install: 入れた先の run.sh でフックが動く" bash -c 'echo "{}" | bash "$1/hooks/run.sh" docs-check' _ "$config"
repo="$work/repo"
mkdir -p "$repo"
git -C "$repo" init -q
echo a >"$repo/a.md"
git -C "$repo" add -A
git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m init
expect OK "install: リンクを通したスキルのスクリプトが lib を読める" bash "$claude/skills/pr-create/scripts/hash-state.sh" "$repo"

out=$(bash "$config/scripts/config-install.sh" 2>&1)
check "install: 置き換えずに走らせ直しても、消えた許可を外す" jq -e '.permissions.allow | index("Bash(retired *)") | not' "$settings.new"
check "install: 置き換えのコマンドで、許可の一覧も一緒に置き換える" grep -q 'claude-config-allow.json.new' <<<"$out"
mv -f "$settings.new" "$settings"
mv -f "$claude/claude-config-allow.json.new" "$claude/claude-config-allow.json"
out=$(bash "$config/scripts/config-install.sh" 2>&1)
check "install: 2 回目は変わらない" grep -q 'OK settings.json は変わらない' <<<"$out"
check "install: 変わらない時は、許可の一覧の案を残さない" test ! -e "$claude/claude-config-allow.json.new"

rm -f "$claude/CLAUDE.md"
echo '# mine' >"$claude/CLAUDE.md"
out=$(bash "$config/scripts/config-install.sh" 2>&1)
status=$?
check "install: 同じ名前の実体があれば止まる" test "$status" -ne 0
check "install: 実体を残す" grep -q '# mine' "$claude/CLAUDE.md"

finish
