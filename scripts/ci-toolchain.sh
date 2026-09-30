#!/bin/zsh
set -euo pipefail
: ${DEVELOPER_DIR:?Select the Xcode 27 developer directory explicitly}
[[ "$(uname -m)" == arm64 ]] || { print -u2 'ARM64 runner required'; exit 69; }
[[ "$(sw_vers -productVersion)" == 27.* ]] || { print -u2 'macOS 27 runner required'; exit 69; }
[[ "$(xcodebuild -version)" == 'Xcode 27.0'* ]] || { print -u2 'Pinned Xcode 27.0 required'; exit 69; }
[[ "$(xcrun --sdk macosx --show-sdk-version)" == 27.0 ]] || { print -u2 'Pinned macOS 27.0 SDK required'; exit 69; }
xcodebuild -version
xcrun --sdk macosx --show-sdk-version
sw_vers
uname -m
