#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
repository_root=${script_directory:h}
configuration=${1:-debug}

case "$configuration" in
  debug|release) ;;
  *)
    print -u2 "Usage: $0 [debug|release]"
    exit 64
    ;;
esac

ordering_trial=${BLENNY_ORDERING_TRIAL:-NO}
shared_system_item_trial=${BLENNY_SHARED_SYSTEM_ITEM_TRIAL:-NO}
code_sign_identity=${BLENNY_CODE_SIGN_IDENTITY:--}
update_feed_url=${BLENNY_UPDATE_FEED_URL:-}
build_number_override=${BLENNY_BUILD_NUMBER:-}

if [[ -z "$code_sign_identity" ]]; then
  print -u2 "BLENNY_CODE_SIGN_IDENTITY must not be empty"
  exit 64
fi
if [[ -n "$update_feed_url" && "$update_feed_url" != https://* ]]; then
  print -u2 "BLENNY_UPDATE_FEED_URL must be an HTTPS URL"
  exit 64
fi
if [[ -n "$update_feed_url" && "$code_sign_identity" == "-" ]]; then
  print -u2 "A Sparkle-enabled package requires a persistent code-signing identity"
  exit 64
fi

if [[ "$ordering_trial" == "YES" ]]; then
  if [[ "$configuration" != "release" ]]; then
    print -u2 "BLENNY_ORDERING_TRIAL=YES requires the release configuration"
    exit 64
  fi

  if [[ "$shared_system_item_trial" == "YES" ]]; then
    print -u2 "BLENNY_ORDERING_TRIAL=YES cannot be combined with BLENNY_SHARED_SYSTEM_ITEM_TRIAL=YES"
    exit 64
  fi
fi

if [[ "$ordering_trial" == "YES" && -z "${BLENNY_BUILD_ROOT:-}" ]]; then
  build_root="$repository_root/build/ordering-trial"
else
  build_root=${BLENNY_BUILD_ROOT:-"$repository_root/build/$configuration"}
fi

scratch_directory="$build_root/swift"
swift_build_options=()

if [[ "$shared_system_item_trial" == "YES" ]]; then
  swift_build_options+=(
    -Xswiftc -DBLENNY_SHARED_SYSTEM_ITEM_TRIAL
    -Xcc -DBLENNY_SHARED_SYSTEM_ITEM_TRIAL=1
  )
fi

if [[ "$ordering_trial" == "YES" ]]; then
  # This optimized owner test retains Debug capability gates; it is not public Release.
  swift_build_options+=(
    -Xswiftc -DDEBUG
    -Xcc -DDEBUG=1
  )
  print -r -- "BLENNY_ORDERING_TRIAL=YES: optimized owner test retains Debug capability gates; not public Release."
fi

swift build --package-path "$repository_root" --scratch-path "$scratch_directory" --configuration "$configuration" --product Blenny "${swift_build_options[@]}"
binary_directory=$(swift build --package-path "$repository_root" --scratch-path "$scratch_directory" --configuration "$configuration" --show-bin-path "${swift_build_options[@]}")

allocate_build_number() {
  if [[ -n "$build_number_override" ]]; then
    if [[ "$build_number_override" != <-> || "$build_number_override" -lt 1 ]]; then
      print -u2 "BLENNY_BUILD_NUMBER must be a positive integer"
      exit 64
    fi
    print -r -- "$build_number_override"
    return
  fi

  local counter_file=${BLENNY_BUILD_NUMBER_FILE:-"$repository_root/LocalData/build-number.txt"}
  local lock_directory="$counter_file.lock"
  local attempts=0
  mkdir -p "${counter_file:h}"
  until mkdir "$lock_directory" 2>/dev/null; do
    attempts=$((attempts + 1))
    if (( attempts >= 200 )); then
      print -u2 "Timed out waiting for the local build-number lock"
      exit 75
    fi
    sleep 0.05
  done
  trap 'rmdir "$lock_directory" 2>/dev/null || true' EXIT INT TERM HUP

  local current=0
  if [[ -f "$counter_file" ]]; then
    current=$(<"$counter_file")
    if [[ "$current" != <-> ]]; then
      print -u2 "Invalid local build-number counter: $counter_file"
      exit 65
    fi
  fi

  local next=$((current + 1))
  local temporary="$counter_file.$$.tmp"
  print -r -- "$next" > "$temporary"
  mv "$temporary" "$counter_file"
  rmdir "$lock_directory"
  trap - EXIT INT TERM HUP
  print -r -- "$next"
}

build_number=$(allocate_build_number)

application_directory="$build_root/Blenny.app"
contents_directory="$application_directory/Contents"
executable_directory="$contents_directory/MacOS"
resources_directory="$contents_directory/Resources"
app_icon_source="$repository_root/Assets/AppIcon/BlennyAppIcon.png"
app_icon_work_directory=$(mktemp -d "${TMPDIR:-/tmp}/blenny-app-icon.XXXXXX")
app_iconset_directory="$app_icon_work_directory/BlennyAppIcon.iconset"

trap 'rm -rf "$app_icon_work_directory"' EXIT

# A prior build may contain a different embedded framework or stale resources.
rm -rf "$application_directory"

app_icon_width=$(/usr/bin/sips -g pixelWidth "$app_icon_source" 2>/dev/null | awk '/pixelWidth/ { print $2 }')
app_icon_height=$(/usr/bin/sips -g pixelHeight "$app_icon_source" 2>/dev/null | awk '/pixelHeight/ { print $2 }')
if [[ "$app_icon_width" != 1024 || "$app_icon_height" != 1024 ]]; then
  print -u2 "BlennyAppIcon.png must be exactly 1024 by 1024 pixels"
  exit 65
fi

mkdir -p "$executable_directory" "$resources_directory"
mkdir -p "$app_iconset_directory"
cp "$binary_directory/Blenny" "$executable_directory/Blenny"
build_framework_rpath="$binary_directory/PackageFrameworks"
if otool -l "$executable_directory/Blenny" | grep -Fq "path $build_framework_rpath "; then
  install_name_tool -delete_rpath "$build_framework_rpath" \
    "$executable_directory/Blenny"
fi
cp "$repository_root/Config/Info.plist" "$contents_directory/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" \
  "$contents_directory/Info.plist"
if [[ "$configuration" == "release" && "$ordering_trial" != "YES" ]]; then
  /usr/libexec/PlistBuddy -c 'Delete :NSAppDataUsageDescription' \
    "$contents_directory/Info.plist"
fi
if [[ -n "$update_feed_url" ]]; then
  plutil -insert SUFeedURL -string "$update_feed_url" \
    "$contents_directory/Info.plist"
fi
cp "$repository_root/Assets/MenuBar/BlennyMenuBarTemplate.svg" "$resources_directory/BlennyMenuBarTemplate.svg"

render_app_icon() {
  local pixel_size=$1
  local filename=$2
  /usr/bin/sips -z "$pixel_size" "$pixel_size" "$app_icon_source" \
    --out "$app_iconset_directory/$filename" >/dev/null
}

render_app_icon 16 icon_16x16.png
render_app_icon 32 icon_16x16@2x.png
render_app_icon 32 icon_32x32.png
render_app_icon 64 icon_32x32@2x.png
render_app_icon 128 icon_128x128.png
render_app_icon 256 icon_128x128@2x.png
render_app_icon 256 icon_256x256.png
render_app_icon 512 icon_256x256@2x.png
render_app_icon 512 icon_512x512.png
render_app_icon 1024 icon_512x512@2x.png
/usr/bin/iconutil --convert icns \
  --output "$resources_directory/BlennyAppIcon.icns" \
  "$app_iconset_directory"

bundle_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$repository_root/Config/Info.plist")
sparkle_source="$binary_directory/Sparkle.framework"
sparkle_target="$contents_directory/Frameworks/Sparkle.framework"
if [[ ! -d "$sparkle_source" ]]; then
  print -u2 "SwiftPM did not produce Sparkle.framework"
  exit 65
fi
mkdir -p "$contents_directory/Frameworks"
ditto "$sparkle_source" "$sparkle_target"
sparkle_current="$sparkle_target/Versions/Current"
for nested in \
  "$sparkle_current/XPCServices/Installer.xpc" \
  "$sparkle_current/XPCServices/Downloader.xpc" \
  "$sparkle_current/Autoupdate" \
  "$sparkle_current/Updater.app"; do
  if [[ ! -e "$nested" ]]; then
    print -u2 "Sparkle component missing: $nested"
    exit 65
  fi
  codesign --force --sign "$code_sign_identity" --options runtime \
    --preserve-metadata=entitlements "$nested"
done
codesign --force --sign "$code_sign_identity" --options runtime \
  "$sparkle_target"
codesign_options=(--force --sign "$code_sign_identity" --identifier "$bundle_identifier")
if [[ "$configuration" == "debug" || "$ordering_trial" == "YES" ]]; then
  codesign_options+=(--entitlements "$repository_root/Config/OrderingTrial.entitlements")
fi
codesign "${codesign_options[@]}" "$application_directory"
codesign --verify --deep --strict "$application_directory"
if [[ -n "$update_feed_url" ]]; then
  requirement=$(codesign -dr - "$application_directory" 2>&1)
  expected_identity_hash=$(<"$repository_root/Config/SigningIdentity.sha1")
  expected_requirement="identifier \"xyz.fi5h.blenny\" and certificate root = H\"${expected_identity_hash:l}\""
  if [[ "$requirement" != *"$expected_requirement"* ]]; then
    print -u2 "A Sparkle-enabled package must use the pinned Blenny signing certificate"
    exit 65
  fi
fi
marketing_version=$(/usr/libexec/PlistBuddy \
  -c 'Print :CFBundleShortVersionString' "$contents_directory/Info.plist")
print -r -- "Built Blenny $marketing_version (Build $build_number)"
print -r -- "$application_directory"
