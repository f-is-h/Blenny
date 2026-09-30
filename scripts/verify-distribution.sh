#!/bin/zsh
set -euo pipefail
repository_root=${0:A:h:h}
app=${1:?Usage: verify-distribution.sh APP}
info="$app/Contents/Info.plist"
read_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$info"; }
[[ "$(read_plist CFBundleIdentifier)" == xyz.fi5h.blenny ]]
[[ "$(read_plist LSMinimumSystemVersion)" == 27.0 ]]
[[ "$(read_plist CFBundleVersion)" == <-> ]]
[[ "$(read_plist CFBundleVersion)" -ge 1 ]]
[[ "$(read_plist CFBundleShortVersionString)" == "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$repository_root/Config/Info.plist")" ]]
[[ -n "$(read_plist NSAccessibilityUsageDescription)" && -n "$(read_plist NSAppDataUsageDescription)" ]]
[[ "$(read_plist SUFeedURL)" == https://raw.githubusercontent.com/f-is-h/Blenny/main/appcast.xml ]]
[[ "$(read_plist SUPublicEDKey)" == "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$repository_root/Config/Info.plist")" ]]
if /usr/libexec/PlistBuddy -c 'Print :BlennyUpdateTest' "$info" >/dev/null 2>&1; then
  print -u2 "Test packages cannot be distributed"; exit 65
fi
for legal_file in LICENSE NOTICE THIRD_PARTY_NOTICES.txt; do
  cmp "$repository_root/$legal_file" "$app/Contents/Resources/$legal_file"
done
[[ -s "$app/Contents/Resources/BlennyAppIcon.icns" ]]
cmp "$repository_root/Assets/MenuBar/BlennyMenuBarTemplate.svg" "$app/Contents/Resources/BlennyMenuBarTemplate.svg"
hash=$(<"$repository_root/Config/SigningIdentity.sha1")
requirement="identifier \"xyz.fi5h.blenny\" and certificate root = H\"${hash:l}\""
codesign --verify --deep --strict -R="$requirement" "$app"
codesign -d --entitlements :- "$app" 2>/dev/null | grep -Fq com.apple.security.files.user-selected.read-write
[[ "$(lipo -archs "$app/Contents/MacOS/Blenny")" == arm64 ]]
if otool -l "$app/Contents/MacOS/Blenny" | awk '$1 == "path" {print $2}' | grep -Evq '^(@loader_path|@executable_path/|/usr/lib/swift$)' ; then
  print -u2 'Non-relative runtime search path found'; exit 65
fi
build_commands=$(otool -l "$app/Contents/MacOS/Blenny")
print -r -- "$build_commands" | grep -Eq 'minos 27\.0$'
print -r -- "$build_commands" | grep -Eq 'sdk 27\.'
string_file=$(mktemp "${TMPDIR:-/tmp}/blenny-distribution-strings.XXXXXX")
trap 'rm -f "$string_file"' EXIT
strings "$app/Contents/MacOS/Blenny" > "$string_file"
grep -Fq TrailingItemPreferredPositions "$string_file"
if grep -Eq 'BLENNY_NOW_PLAYING_VALIDATION|BLENNY_DRAG_DIAGNOSTIC|BLENNY_ORDERING_DIAGNOSTICS_DIRECTORY|BlennyUpdateTestRoot' "$string_file"; then
  print -u2 "Diagnostic/test entry point found in distribution package"; exit 65
fi
print "Distribution identity, resources, product capability and diagnostic exclusion: PASS"
