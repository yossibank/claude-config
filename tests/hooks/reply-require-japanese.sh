#!/bin/bash
set -uo pipefail

source "$(dirname "$0")/../support/assert.sh"
source "$(dirname "$0")/../support/fixtures.sh"
source "$(dirname "$0")/../support/hook_fixtures.sh"
STOP="日本語で書き直す"

english="The fixes are done and make verify passed, but make test failed in one suite."
japanese="3 件の直しは終わり、make verify も通りました。ただ make test が 1 件落ちています。"
reply() {
    jq -nc --arg text "$1" '{last_assistant_message: $text}'
}

run reply-require-japanese 2 "ja: 英語の返事は止める" "$(reply "$english")"
run reply-require-japanese 0 "ja: 日本語の返事は通す" "$(reply "$japanese")"
run reply-require-japanese 0 "ja: 識別子や英語の名前が混ざっても、日本語が多ければ通す" \
    "$(reply "EntryVoiceFlow と EntryVoiceListener を直し、make verify と make test を通しました。")"
run reply-require-japanese 0 "ja: コードのブロックとインラインのコードは数えない" \
    "$(reply $'直しました。\n```swift\nlet value = try await source.start(hints: hints) { event in receive(event) }\n```\n`git push -u origin feat/voice-entry` で出します。')"
run reply-require-japanese 0 "ja: 短い英語は通す" "$(reply "Done.")"
run reply-require-japanese 0 "ja: 止めた後の 2 回目は通す" \
    "$(jq -nc --arg text "$english" '{last_assistant_message: $text, stop_hook_active: true}')"
run reply-require-japanese 0 "ja: 壊れた入力では止めない" "not json"

transcript="$work/transcript.jsonl"
{
    jq -nc --arg text "$japanese" '{type: "assistant", message: {content: [{type: "text", text: $text}]}}'
    jq -nc '{type: "user", message: {content: "日本語で"}}'
    jq -nc --arg text "$english" '{type: "assistant", message: {content: [{type: "text", text: $text}]}}'
    jq -nc '{type: "assistant", message: {content: [{type: "tool_use", name: "Bash"}]}}'
} >"$transcript"
run reply-require-japanese 2 "ja: 記録から最後の文の返事を読んで止める" "$(jq -nc --arg path "$transcript" '{transcript_path: $path}')"
jq -nc '{type: "user", message: {content: [{type: "tool_result", content: "ok"}]}}' >>"$transcript"
run reply-require-japanese 2 "ja: 道具の結果を挟んでも、同じターンの英語の返事は止める" "$(jq -nc --arg path "$transcript" '{transcript_path: $path}')"
jq -nc '{type: "user", message: {content: "続けて"}}' >>"$transcript"
jq -nc '{type: "assistant", message: {content: [{type: "tool_use", name: "Bash"}]}}' >>"$transcript"
run reply-require-japanese 0 "ja: 今のターンに文の返事が無ければ、前のターンの英語は見ない" "$(jq -nc --arg path "$transcript" '{transcript_path: $path}')"
run reply-require-japanese 0 "ja: 記録が無ければ通す" "$(jq -nc --arg path "$work/none.jsonl" '{transcript_path: $path}')"

turn="$work/turn.jsonl"
call() {
    jq -nc --arg path "$turn" --arg id "$1" '{transcript_path: $path, session_id: $id, tool_name: "Bash"}'
}
{
    head -c 70000 /dev/zero | tr '\0' a
    echo
    jq -nc '{type: "user", message: {content: "PR を作って"}}'
    jq -nc --arg text "$english" '{type: "assistant", uuid: "u1", message: {content: [{type: "text", text: $text}]}}'
    jq -nc '{type: "assistant", uuid: "u2", message: {content: [{type: "tool_use", name: "Bash"}]}}'
    jq -nc '{type: "user", message: {content: [{type: "tool_result", content: "ok"}]}}'
} >"$turn"
STOP="「The fixes are done and make verify passed"
run reply-require-japanese 2 "ja pre: 大きい記録の末尾から、途中の英語の一言を見つけて次の道具を止める" "$(call s1)" pre
run reply-require-japanese 0 "ja pre: 一度止めた一言では、二度は止めない" "$(call s1)" pre
run reply-require-japanese 2 "ja pre: 別の会話では、同じ一言でも止める" "$(call s2)" pre
fenced="$work/fenced.jsonl"
jq -nc --arg text $'```bash\nmake verify\n```\n'"$english" '{type: "assistant", uuid: "f1", message: {content: [{type: "text", text: $text}]}}' >"$fenced"
run reply-require-japanese 2 "ja pre: コードのブロックから始まる一言は、地の文の書き出しを引く" \
    "$(jq -nc --arg path "$fenced" '{transcript_path: $path, session_id: "s5"}')" pre
run reply-require-japanese 0 "ja pre: サブエージェントの道具は、親の一言で止めない" "$(call s4 | jq -c '.agent_id = "a1"')" pre
jq -nc --arg text "$japanese" '{type: "assistant", uuid: "u3", message: {content: [{type: "text", text: $text}]}}' >>"$turn"
run reply-require-japanese 0 "ja pre: 書き直した日本語の一言は通す" "$(call s1)" pre
jq -nc --arg text "$english" '{type: "assistant", uuid: "u4", message: {content: [{type: "text", text: $text}]}}' >>"$turn"
jq -nc '{type: "user", message: {content: "続けて"}}' >>"$turn"
run reply-require-japanese 0 "ja pre: 人の文の後に一言が無ければ、前のターンの英語は見ない" "$(call s3)" pre

finish
