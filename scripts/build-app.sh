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

swift build --package-path "$repository_root" --configuration "$configuration" --product Blenny
binary_directory=$(swift build --package-path "$repository_root" --configuration "$configuration" --show-bin-path)

application_directory="$repository_root/build/$configuration/Blenny.app"
contents_directory="$application_directory/Contents"
executable_directory="$contents_directory/MacOS"
resources_directory="$contents_directory/Resources"
app_icon_source="$repository_root/Assets/AppIcon/BlennyAppIcon.png"
app_icon_work_directory=$(mktemp -d "${TMPDIR:-/tmp}/blenny-app-icon.XXXXXX")
app_iconset_directory="$app_icon_work_directory/BlennyAppIcon.iconset"

trap 'rm -rf "$app_icon_work_directory"' EXIT

app_icon_width=$(/usr/bin/sips -g pixelWidth "$app_icon_source" 2>/dev/null | awk '/pixelWidth/ { print $2 }')
app_icon_height=$(/usr/bin/sips -g pixelHeight "$app_icon_source" 2>/dev/null | awk '/pixelHeight/ { print $2 }')
if [[ "$app_icon_width" != 1024 || "$app_icon_height" != 1024 ]]; then
  print -u2 "BlennyAppIcon.png must be exactly 1024 by 1024 pixels"
  exit 65
fi

mkdir -p "$executable_directory" "$resources_directory"
mkdir -p "$app_iconset_directory"
cp "$binary_directory/Blenny" "$executable_directory/Blenny"
cp "$repository_root/Config/Info.plist" "$contents_directory/Info.plist"
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
codesign --force --sign - --identifier "$bundle_identifier" "$application_directory"
print -r -- "$application_directory"
