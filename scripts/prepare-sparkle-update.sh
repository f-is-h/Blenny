#!/bin/zsh
set -euo pipefail
repository_root=${0:A:h:h}
(( $# == 3 )) || { print -u2 "Usage: $0 SIGNED-APP HTTPS-DOWNLOAD-PREFIX OUTPUT-DIRECTORY"; exit 64; }
app=${1:A}
prefix=$2
output=${3:A}
[[ "$prefix" == https://* ]] || { print -u2 "HTTPS downloads required"; exit 64; }
zsh "$repository_root/scripts/verify-distribution.sh" "$app"
info="$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info")
name="Blenny-${version}.dmg"
mkdir -p "$output"
archive="$output/$name"
[[ ! -e "$archive" ]] || { print -u2 "Refusing to replace immutable archive"; exit 73; }
staging=$(mktemp -d "${TMPDIR:-/tmp}/blenny-dmg.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/Blenny.app"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname Blenny -srcfolder "$staging" -format UDZO "$archive"
hdiutil verify "$archive" >/dev/null
python3 "$repository_root/scripts/verify-dmg.py" "$archive" --expected-app "$app"
tools=${BLENNY_SPARKLE_TOOLS_DIR:-"$repository_root/.build/artifacts/sparkle/Sparkle/bin"}
[[ -x "$tools/sign_update" ]] || { print -u2 "Pinned Sparkle signing tool missing"; exit 69; }
signing_arguments=(--account xyz.fi5h.blenny)
if [[ -n "${BLENNY_SPARKLE_KEY_FILE:-}" ]]; then
  signing_arguments=(--ed-key-file "$BLENNY_SPARKLE_KEY_FILE")
fi
signature=$("$tools/sign_update" "${signing_arguments[@]}" -p "$archive")
"$tools/sign_update" "${signing_arguments[@]}" --verify "$archive" "$signature"
(cd "$output" && shasum -a 256 "$name" > "$name.sha256")
if [[ -f "$repository_root/appcast.xml" ]]; then
  cp "$repository_root/appcast.xml" "$output/appcast.xml"
fi
python3 "$repository_root/scripts/create-appcast.py" --feed "$output/appcast.xml" \
  --archive "$archive" --version "$version" --build "$build" --signature "$signature" \
  --download-url "${prefix%/}/$name" \
  --release-url "https://github.com/f-is-h/Blenny/releases/tag/v$version" \
  --notes "$repository_root/docs/RELEASE_NOTES.md"
python3 - "$app" "$archive" "$signature" "$repository_root" <<'RECEIPT'
import hashlib,json,os,plistlib,subprocess,sys
from pathlib import Path
app,archive,signature,repo=sys.argv[1:]
sys.path.insert(0,str(Path(repo)/'scripts'))
from release_tools import product_digest,version_notes
info=plistlib.loads((Path(app)/'Contents/Info.plist').read_bytes())
p=Path(archive)
receipt={'version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],
         'archive':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
         'length':p.stat().st_size,'edSignature':signature,
         'sourceCommit':subprocess.check_output(['git','-C',repo,'rev-parse','HEAD'],text=True).strip(),
         'sourceDirty':bool(subprocess.check_output(['git','-C',repo,'status','--porcelain'],text=True)),
         'productDigest':product_digest(Path(repo)),
         'releaseNotesSHA256':hashlib.sha256(version_notes(info['CFBundleShortVersionString'],Path(repo)).encode()).hexdigest(),
         'buildOrigin':'github-actions' if os.getenv('GITHUB_ACTIONS')=='true' else 'local-development',
         'tag':os.getenv('BLENNY_RELEASE_TAG'),
         'workflowRun':os.getenv('GITHUB_RUN_ID'), 'workflowAttempt':os.getenv('GITHUB_RUN_ATTEMPT'),
         'toolchain':{'os':subprocess.check_output(['sw_vers','-productVersion'],text=True).strip(),
                      'osBuild':subprocess.check_output(['sw_vers','-buildVersion'],text=True).strip(),
                      'architecture':subprocess.check_output(['uname','-m'],text=True).strip(),
                      'xcode':subprocess.check_output(['xcodebuild','-version'],text=True).strip(),
                      'sdk':subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-version'],text=True).strip()},
         'verification':{'distribution':True,'mountedContents':True}}
if os.getenv('BLENNY_SPARKLE_FIXTURE_RECEIPT'):
    fixture=json.loads(Path(os.environ['BLENNY_SPARKLE_FIXTURE_RECEIPT']).read_text())
    assert all(fixture[x]['passed'] for x in ('cancel','equal','older','unavailable','wrong-signature','tampered','install'))
    assert all(fixture[x] is True for x in ('signature-tamper-rejected','policy-and-recovery-unchanged','sparkle-preferences-restored'))
    receipt['sparkleFixtureVerified']=True
p.with_suffix('.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
(p.parent/'release-notes.md').write_text(version_notes(info['CFBundleShortVersionString'],Path(repo)))
RECEIPT
python3 "$repository_root/scripts/verify-artifact.py" "$output"
print "Prepared signed DMG, checksum, receipt and appcast under $output"
print "Public download/feed delivery requires separately authorized publication."
