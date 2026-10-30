#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../../lib/build_log.sh"

[[ $# -ge 3 ]] || { echo "NG 使い方: $(basename "$0") <ワークスペース> <スキーム> <出力先のフォルダ>"; exit 1; }

workspace="$1"
scheme="$2"
out=$(mkdir -p "$3" && cd "$3" && pwd)
archive="$out/$scheme.xcarchive"
log="$out/archive.log"
options="$out/ExportOptions.plist"
destination="${CC_STORE_DESTINATION:-upload}"
[[ -z ${CC_STORE_EXPORT:-}${CC_STORE_ARCHIVE_ONLY:-} ]] || { echo "NG CC_STORE_EXPORT と CC_STORE_ARCHIVE_ONLY は読まない。CC_STORE_DESTINATION にする"; exit 1; }

case "$destination" in
    upload | export | archive) ;;
    *) echo "NG CC_STORE_DESTINATION は upload・export・archive のどれかにする: $destination"; exit 1 ;;
esac

fail_with_log() {
    show_errors "$log" first
    echo "NG ${1}（ログ: ${log}）"
    exit 1
}

team=$(xcodebuild -workspace "$workspace" -scheme "$scheme" -showBuildSettings 2>/dev/null | awk '!team && $1 == "DEVELOPMENT_TEAM" { team = $3 } END { print team }') || team=""
[[ -n $team ]] || { echo "NG DEVELOPMENT_TEAM が見つからない"; exit 1; }

if [[ $destination != archive ]]; then
cat >|"$options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>$destination</string>
	<key>teamID</key>
	<string>$team</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>manageAppVersionAndBuildNumber</key>
	<true/>
</dict>
</plist>
PLIST
fi

xcodebuild archive \
    -workspace "$workspace" \
    -scheme "$scheme" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$archive" \
    -allowProvisioningUpdates >|"$log" 2>&1 || fail_with_log "アーカイブ"
echo "OK アーカイブ $archive"

[[ $destination == archive ]] && exit 0

xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportPath "$out/export" \
    -exportOptionsPlist "$options" \
    -allowProvisioningUpdates >>"$log" 2>&1 || fail_with_log "書き出し・送信"
echo "OK ${destination}（ログ: ${log}）"
