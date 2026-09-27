#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
repository_root=${script_directory:h}

if (( $# != 3 )); then
  print -u2 "Usage: $0 <signed-Blenny.app> <HTTPS-download-URL-prefix> <output-directory>"
  exit 64
fi

application_directory=${1:A}
download_url_prefix=$2
output_directory=${3:A}

if [[ ! -d "$application_directory" || "${application_directory:t}" != "Blenny.app" ]]; then
  print -u2 "Expected a signed Blenny.app bundle"
  exit 64
fi
if [[ "$download_url_prefix" != https://* ]]; then
  print -u2 "Update downloads must use HTTPS"
  exit 64
fi

info_plist="$application_directory/Contents/Info.plist"
read_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$2"; }

bundle_identifier=$(read_plist CFBundleIdentifier "$info_plist")
if [[ "$bundle_identifier" != xyz.fi5h.blenny ]]; then
  print -u2 "Unexpected bundle identifier: $bundle_identifier"
  exit 65
fi
feed_url=$(read_plist SUFeedURL "$info_plist")
if [[ "$feed_url" != https://* ]]; then
  print -u2 "The app must contain its production HTTPS SUFeedURL"
  exit 65
fi
public_key=$(read_plist SUPublicEDKey "$info_plist")
expected_key=$(read_plist SUPublicEDKey "$repository_root/Config/Info.plist")
if [[ "$public_key" != "$expected_key" ]]; then
  print -u2 "The app's Sparkle public key differs from the repository key"
  exit 65
fi

codesign --verify --deep --strict "$application_directory"
requirement=$(codesign -dr - "$application_directory" 2>&1)
expected_identity_hash=$(<"$repository_root/Config/SigningIdentity.sha1")
expected_requirement="identifier \"xyz.fi5h.blenny\" and certificate root = H\"${expected_identity_hash:l}\""
if [[ "$requirement" != *"$expected_requirement"* ]]; then
  print -u2 "The app is not signed with the pinned Blenny certificate"
  exit 65
fi

version=$(read_plist CFBundleShortVersionString "$info_plist")
build_number=$(read_plist CFBundleVersion "$info_plist")
archive_name="Blenny-${version}-${build_number}.zip"
mkdir -p "$output_directory"
archive_path="$output_directory/$archive_name"
if [[ -e "$archive_path" ]]; then
  print -u2 "Refusing to overwrite an existing update archive: $archive_path"
  exit 73
fi

ditto -c -k --sequesterRsrc --keepParent "$application_directory" "$archive_path"
sparkle_tools=${BLENNY_SPARKLE_TOOLS_DIR:-"$repository_root/.build/artifacts/sparkle/Sparkle/bin"}
if [[ ! -x "$sparkle_tools/generate_appcast" && -z "${BLENNY_SPARKLE_TOOLS_DIR:-}" ]]; then
  sparkle_tools="${application_directory:h}/swift/artifacts/sparkle/Sparkle/bin"
fi
if [[ ! -x "$sparkle_tools/generate_appcast" ]]; then
  print -u2 "Resolve the pinned Sparkle package before preparing updates"
  exit 69
fi
"$sparkle_tools/generate_appcast" \
  --account xyz.fi5h.blenny \
  --download-url-prefix "$download_url_prefix" \
  --maximum-deltas 0 \
  --maximum-versions 1 \
  -o "$output_directory/appcast.xml" \
  "$output_directory"

appcast_path="$output_directory/appcast.xml"
xmllint --noout "$appcast_path"
if ! grep -Fq "$archive_name" "$appcast_path"; then
  print -u2 "The generated appcast does not reference the update archive"
  exit 65
fi
print -r -- "Prepared signed update: $archive_path"
print -r -- "Prepared appcast: $appcast_path"
print -r -- "Publish only after the hosted feed and a real update install are verified."
