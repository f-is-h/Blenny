#!/bin/zsh
set -euo pipefail
[[ "${GITHUB_ACTIONS:-false}" == true && "${GITHUB_REPOSITORY:-}" == f-is-h/Blenny ]] || { print -u2 'Hosted signing only'; exit 64; }
: ${BLENNY_CERTIFICATE_P12_BASE64:?Missing Blenny certificate secret}
: ${BLENNY_CERTIFICATE_PASSWORD:?Missing Blenny certificate password secret}
: ${BLENNY_SPARKLE_PRIVATE_KEY:?Missing Blenny Sparkle secret}
tools_root=${0:A:h:h}
root=${BLENNY_RELEASE_SOURCE_ROOT:-$tools_root}
root=${root:A}
output=${1:?Usage: ci-sign-package.sh OUTPUT BUILD}
build=${2:?Usage: ci-sign-package.sh OUTPUT BUILD}
diagnostics_only=${BLENNY_SIGNING_DIAGNOSTICS_ONLY:-false}
[[ "$diagnostics_only" == true || "$diagnostics_only" == false ]] || { print -u2 'Invalid signing diagnostics mode'; exit 64; }
diagnostic_report="$root/LocalData/ci/signing-diagnostic.json"
secret_directory=$(mktemp -d "${RUNNER_TEMP:?}/blenny-signing.XXXXXX")
chmod 700 "$secret_directory"
keychain="$secret_directory/signing.keychain-db"
keychain_password=$(openssl rand -hex 32)
certificate="$secret_directory/pinned-certificate.pem"
trust_backup="$secret_directory/admin-trust-before.plist"
trust_changed=NO
# The hosted runner is ephemeral. Retain its search list and default keychain.
search_list=(${(f)"$(security list-keychains -d user | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//')"})
default_keychain=$(security default-keychain -d user | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//')
cleanup() {
  local trust_restore_failed=NO
  if [[ "$trust_changed" == YES ]]; then
    sudo -n security remove-trusted-cert -d "$certificate" || trust_restore_failed=YES
    if [[ -f "$trust_backup" ]]; then
      sudo -n security trust-settings-import -d "$trust_backup" || trust_restore_failed=YES
    fi
  fi
  security default-keychain -d user -s "$default_keychain" || true
  security list-keychains -d user -s "${search_list[@]}" || true
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  rm -rf "$secret_directory"
  if [[ "$trust_restore_failed" == YES ]]; then
    print -u2 'Hosted admin trust restoration failed; refusing successful signing completion'
    exit 65
  fi
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
security find-certificate -a -p "$keychain" > "$secret_directory/imported-certificates.pem"
# Compare the public certificate bytes before granting any trust. P12 import
# does not transfer the owner's trust settings to a fresh hosted runner.
python3 - "$secret_directory/imported-certificates.pem" "$certificate" "$pinned_identity" "$diagnostic_report" <<'CERTIFICATE'
import base64, hashlib, json, os, re, sys
from pathlib import Path
source, destination, pinned, report = sys.argv[1:]
blocks = re.findall(r"-----BEGIN CERTIFICATE-----\s*([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----", Path(source).read_text())
matches = []
fingerprints = []
for block in blocks:
    der = base64.b64decode("".join(block.split()), validate=True)
    fingerprint = hashlib.sha1(der).hexdigest().upper()
    fingerprints.append(fingerprint)
    if fingerprint == pinned:
        matches.append(block)
result = dict(schema=1, sourceCommit=os.getenv('BLENNY_RELEASE_SOURCE_SHA', os.environ['GITHUB_SHA']),
              workflowCommit=os.environ['GITHUB_SHA'], workflowRun=os.getenv('GITHUB_RUN_ID'),
              expectedFingerprint=pinned, importedFingerprints=fingerprints, certificateMatchesPin=len(matches)==1)
if len(matches) != 1:
    result['cause'] = 'certificate-fingerprint-mismatch'
path = Path(report)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(result, indent=2) + '\n')
if len(matches) != 1:
    print("Imported certificate fingerprints: " + ", ".join(fingerprints), file=sys.stderr)
    raise SystemExit("Imported certificate does not match the pinned Blenny fingerprint")
Path(destination).write_text("-----BEGIN CERTIFICATE-----\n" + "".join(matches[0].split()) + "\n-----END CERTIFICATE-----\n")
CERTIFICATE
all_identities=$(security find-identity -p codesigning "$keychain")
valid_identities_before=$(security find-identity -v -p codesigning "$keychain")
identity_present=false
valid_before=false
[[ "$all_identities" == *"$pinned_identity"* ]] && identity_present=true
[[ "$valid_identities_before" == *"$pinned_identity"* ]] && valid_before=true
python3 - "$diagnostic_report" "$identity_present" "$valid_before" <<'BEFORE_TRUST'
import json,sys
from pathlib import Path
path=Path(sys.argv[1]); result=json.loads(path.read_text())
result.update(pinnedIdentityPresent=sys.argv[2]=='true', validIdentityBeforeTrust=sys.argv[3]=='true')
if not result['pinnedIdentityPresent']:
    result['cause']='matching-certificate-has-no-usable-private-key'
path.write_text(json.dumps(result,indent=2)+'\n')
print('Pinned certificate matches: true; identity present: '+sys.argv[2]+'; valid before trust: '+sys.argv[3])
BEFORE_TRUST
[[ "$identity_present" == true ]] || { print -u2 'Pinned certificate has no matching code-signing private-key identity'; exit 65; }
if ! security trust-settings-export -d "$trust_backup" > "$secret_directory/trust-export.log" 2>&1; then
  if ! grep -Fq 'No Trust Settings were found' "$secret_directory/trust-export.log"; then
    print -u2 'Cannot snapshot hosted admin trust settings; refusing to change trust'
    exit 65
  fi
  rm -f "$trust_backup"
fi
trust_changed=YES
# This script is hosted-only. Trust is constrained to code signing, and the
# runner's prior admin trust settings are restored on every exit path.
sudo -n security add-trusted-cert -d -r trustRoot -p codeSign -k "$keychain" "$certificate"
valid_identities_after=$(security find-identity -v -p codesigning "$keychain")
valid_after=false
[[ "$valid_identities_after" == *"$pinned_identity"* ]] && valid_after=true
python3 - "$diagnostic_report" "$valid_after" <<'AFTER_TRUST'
import json,sys
from pathlib import Path
path=Path(sys.argv[1]); result=json.loads(path.read_text())
result['validIdentityAfterTrust']=sys.argv[2]=='true'
result['cause']=('unusable-identity-after-trust' if not result['validIdentityAfterTrust'] else
                 'identity-already-valid' if result['validIdentityBeforeTrust'] else
                 'missing-hosted-code-signing-trust')
path.write_text(json.dumps(result,indent=2)+'\n')
print('Valid identity after trust: '+sys.argv[2]+'; diagnosis: '+result['cause'])
AFTER_TRUST
[[ "$valid_after" == true ]] || { print -u2 'Pinned certificate has no valid usable code-signing identity after hosted trust setup'; exit 65; }
if [[ "$diagnostics_only" == true ]]; then
  print 'Signing diagnosis complete; no application build or publication was performed'
  exit 0
fi
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
python3 - "$output" "$root" <<'CONTROLLER_RECEIPT'
import json,os,plistlib,sys
from pathlib import Path
output,root=map(Path,sys.argv[1:])
version=plistlib.loads((root/'Config/Info.plist').read_bytes())['CFBundleShortVersionString']
path=output/f'Blenny-{version}.receipt.json'
receipt=json.loads(path.read_text())
receipt['workflowCommit']=os.environ['GITHUB_SHA']
path.write_text(json.dumps(receipt,indent=2)+'\n')
CONTROLLER_RECEIPT
# Independent pinned-public-key verification also rejects an unrelated Sparkle secret.
python3 "$tools_root/scripts/verify-artifact.py" "$output" --source "${BLENNY_RELEASE_SOURCE_SHA:-$GITHUB_SHA}"
