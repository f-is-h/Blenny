#!/bin/zsh
set -euo pipefail
repository_root=${0:A:h:h}
: ${DEVELOPER_DIR:?Select the Xcode 27 developer directory explicitly}
[[ "$(xcodebuild -version)" == 'Xcode 27.'* ]] || { print -u2 'Xcode 27 required'; exit 69; }
[[ "$(xcrun --sdk macosx --show-sdk-version)" == 27.* ]] || { print -u2 'macOS 27 SDK required'; exit 69; }
cd "$repository_root"
git diff --check
python3 scripts/test-appcast.py
python3 scripts/test-release-tools.py
python3 scripts/test-ci-release.py
python3 scripts/release_tools.py check
python3 scripts/check-workflows.py
python3 scripts/lint-workflows.py
for configuration in debug release; do
  xcrun swift test --configuration "$configuration"
  xcrun swift build --configuration "$configuration" --product Blenny
done
print 'Local deterministic verification: PASS'
