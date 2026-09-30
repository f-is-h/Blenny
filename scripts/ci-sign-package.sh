#!/bin/zsh
set -euo pipefail
[[ "${GITHUB_ACTIONS:-false}" == true && "${GITHUB_REPOSITORY:-}" == f-is-h/Blenny ]] || { print -u2 'Hosted signing only'; exit 64; }
: ${BLENNY_CERTIFICATE_P12_BASE64:?Missing Blenny certificate secret}
: ${BLENNY_CERTIFICATE_PASSWORD:?Missing Blenny certificate password secret}
: ${BLENNY_SPARKLE_PRIVATE_KEY:?Missing Blenny Sparkle secret}
root=${0:A:h:h}
output=${1:?Usage: ci-sign-package.sh OUTPUT BUILD}
build=${2:?Usage: ci-sign-package.sh OUTPUT BUILD}
secret_directory=$(mktemp -d "${RUNNER_TEMP:?}/blenny-signing.XXXXXX")
chmod 700 "$secret_directory"
keychain="$secret_directory/signing.keychain-db"
keychain_password=$(openssl rand -hex 32)
# The hosted runner is ephemeral. Retain its search list and default keychain.
search_list=(${(f)"$(security list-keychains -d user | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//')"})
default_keychain=$(security default-keychain -d user | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//')
cleanup() {
  security default-keychain -d user -s "$default_keychain" || true
  security list-keychains -d user -s "${search_list[@]}" || true
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  rm -rf "$secret_directory"
}
trap cleanup EXIT INT TERM HUP
print -rn -- "$BLENNY_CERTIFICATE_P12_BASE64" | base64 --decode > "$secret_directory/certificate.p12"
print -rn -- "$BLENNY_SPARKLE_PRIVATE_KEY" > "$secret_directory/sparkle-secret"
chmod 600 "$secret_directory/certificate.p12" "$secret_directory/sparkle-secret"
unset BLENNY_CERTIFICATE_P12_BASE64 BLENNY_SPARKLE_PRIVATE_KEY
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 3600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$secret_directory/certificate.p12" -k "$keychain" -P "$BLENNY_CERTIFICATE_PASSWORD" -T /usr/bin/codesign >/dev/null
unset BLENNY_CERTIFICATE_PASSWORD
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" "${search_list[@]}"
security default-keychain -d user -s "$keychain"
pinned_identity=$(<"$root/Config/SigningIdentity.sha1")
security find-identity -v -p codesigning "$keychain" | grep -Fq "$pinned_identity" || { print -u2 'Imported certificate is not the pinned Blenny identity'; exit 65; }
export BLENNY_SPARKLE_KEY_FILE="$secret_directory/sparkle-secret"
# Exercise the exact source through a separate manager-free Sparkle fixture.
# This flavor cannot pass distribution verification and is never uploaded.
BLENNY_BUILD_ROOT="$root/LocalData/ci/sparkle/template" \
BLENNY_SWIFT_SCRATCH_PATH="$root/LocalData/ci/sparkle/swift" \
BLENNY_BUILD_NUMBER=101 BLENNY_UPDATE_TEST=YES \
BLENNY_UPDATE_FEED_URL=http://127.0.0.1:8765/appcast.xml \
zsh "$root/scripts/build-app.sh" release
python3 "$root/scripts/test-sparkle-local.py" "$root/LocalData/ci/sparkle/template/Blenny.app" "$root/LocalData/ci/sparkle/run"
export BLENNY_SPARKLE_FIXTURE_RECEIPT="$root/LocalData/ci/sparkle/run/results.json"
zsh "$root/scripts/prepare-release.sh" "$build" "$output"
# Independent pinned-public-key verification also rejects an unrelated Sparkle secret.
python3 "$root/scripts/verify-artifact.py" "$output" --source "$GITHUB_SHA"
