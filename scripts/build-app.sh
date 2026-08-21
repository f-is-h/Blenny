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

mkdir -p "$executable_directory"
cp "$binary_directory/Blenny" "$executable_directory/Blenny"
cp "$repository_root/Config/Info.plist" "$contents_directory/Info.plist"

bundle_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$repository_root/Config/Info.plist")
codesign --force --sign - --identifier "$bundle_identifier" "$application_directory"
print -r -- "$application_directory"
