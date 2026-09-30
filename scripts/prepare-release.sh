#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
build_number=${1:?Usage: prepare-release.sh BUILD-NUMBER [OUTPUT-DIRECTORY]}
[[ "$build_number" == <-> && "$build_number" -ge 100 ]] || { print -u2 "Release build must be at least 100 and increase for every published update"; exit 64; }
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root/Config/Info.plist")
python3 "$root/scripts/release_tools.py" check
output=${2:-"$root/LocalData/releases/$version-$build_number"}
[[ ! -e "$output/Blenny-$version.dmg" ]] || { print -u2 "Refusing to modify an existing immutable release directory"; exit 73; }
for flag in BLENNY_ORDERING_TRIAL BLENNY_SHARED_SYSTEM_ITEM_TRIAL BLENNY_NOW_PLAYING_LEGACY_REVEAL_TRIAL BLENNY_UPDATE_TEST BLENNY_ALLOW_ADHOC; do
  [[ "${(P)flag:-NO}" != YES ]] || { print -u2 "Release preparation rejects test/development overrides"; exit 64; }
done
[[ -z "${BLENNY_UPDATE_FEED_URL:-}" ]] || { print -u2 "Release preparation uses the canonical production feed"; exit 64; }
export BLENNY_BUILD_NUMBER="$build_number"
export BLENNY_BUILD_ROOT="$output/package"
export BLENNY_SWIFT_SCRATCH_PATH=${BLENNY_SWIFT_SCRATCH_PATH:-"$root/.build"}
zsh "$root/scripts/build-app.sh" release
zsh "$root/scripts/prepare-sparkle-update.sh" "$output/package/Blenny.app" \
  "https://github.com/f-is-h/Blenny/releases/download/v$version" "$output"
