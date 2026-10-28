#!/bin/bash
set -euo pipefail

workspace="${1:?ワークスペース}"
scheme="${2:?スキーム}"
out=$(mkdir -p "${3:?出力先のフォルダ}" && cd "$3" && pwd)
archive="$out/$scheme.xcarchive"
log="$out/archive.log"
options="$out/ExportOptions.plist"
destination="${EXPORT_DESTINATION:-upload}"

case "$destination" in
    upload | export) ;;
    *) echo "NG EXPORT_DESTINATION は upload か export にする: $destination"; exit 1 ;;
esac

team=$(xcodebuild -workspace "$workspace" -scheme "$scheme" -showBuildSettings 2>/dev/null | awk '!team && $1 == "DEVELOPMENT_TEAM" { team = $3 } END { print team }')
[ -n "$team" ] || { echo "NG DEVELOPMENT_TEAM が見つからない"; exit 1; }

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

xcodebuild archive \
    -workspace "$workspace" \
    -scheme "$scheme" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$archive" \
    -allowProvisioningUpdates >|"$log" 2>&1 || { { grep -E "error:" "$log" || true; } | sort -u | head -20; echo "NG アーカイブ（全ログ: ${log}）"; exit 1; }
echo "OK アーカイブ $archive"

[ "${ARCHIVE_ONLY:-0}" = 1 ] && exit 0

xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportPath "$out/export" \
    -exportOptionsPlist "$options" \
    -allowProvisioningUpdates >>"$log" 2>&1 || { { grep -E "error:" "$log" || true; } | sort -u | head -20; echo "NG 書き出し・送信（全ログ: ${log}）"; exit 1; }
echo "OK ${destination}（全ログ: ${log}）"
