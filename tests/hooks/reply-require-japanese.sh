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
run reply-require-japanese 0 "ja: 記録が無ければ通す" "$(jq -nc --arg path "$work/none.jsonl" '{transcript_path: $path}')"

finish
