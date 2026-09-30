#!/usr/bin/env python3
"""Bounded Sparkle integration test. Requires an explicitly built test flavor."""
import argparse
import base64
import functools
import hashlib
import http.server
import json
import os
import plistlib
import shutil
import subprocess
import tempfile
import threading
from pathlib import Path
from release_tools import marketing_version

REPO = Path(__file__).resolve().parent.parent
DOMAIN = 'xyz.fi5h.blenny'

def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, **kwargs)

def preferences():
    result = subprocess.run(['defaults', 'export', DOMAIN, '-'], capture_output=True)
    return plistlib.loads(result.stdout) if result.returncode == 0 else {}

def configure(app, root, mode, build):
    info = app / 'Contents/Info.plist'
    data = plistlib.loads(info.read_bytes())
    assert data.get('BlennyUpdateTest') is True, 'Only test flavor allowed'
    assert data['CFBundleIdentifier'] == DOMAIN
    data.update(BlennyUpdateTestRoot=str(root), BlennyUpdateTestMode=mode, CFBundleVersion=str(build))
    info.write_bytes(plistlib.dumps(data))
    identity = (REPO / 'Config/SigningIdentity.sha1').read_text().strip()
    run('codesign', '--force', '--sign', identity, '--identifier', DOMAIN,
        '--entitlements', str(REPO / 'Config/OrderingTrial.entitlements'), str(app))
    run('codesign', '--verify', '--deep', '--strict', str(app))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('template', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    template, root = args.template.resolve(), args.output.resolve()
    assert b'BlennyUpdateTestRoot' in (template / 'Contents/MacOS/Blenny').read_bytes(), 'Test driver must be compiled into fixture; refusing ordinary manager'
    assert subprocess.run(['pgrep', '-x', 'Blenny'], capture_output=True).returncode == 1, 'Quit Blenny before testing'

    assert root.is_relative_to(REPO / "LocalData"), "Keep fixtures under ignored LocalData"
    assert not root.exists(), 'Use a fresh disposable output directory'
    root.mkdir(parents=True, mode=0o700)
    prior = preferences()
    # Preserve product state and recovery receipts; test hosts never initialize management.
    state_root = Path.home() / 'Library/Application Support/Blenny'
    before = {str(p.relative_to(state_root)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in state_root.rglob('*') if p.is_file()} if state_root.exists() else {}
    (root / 'preferences-before.plist').write_bytes(plistlib.dumps(prior))
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(root))
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 8765), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    results = {}
    try:
        target = root / 'target/Blenny.app'
        target.parent.mkdir()
        run('ditto', str(template), str(target))
        configure(target, root, 'install', 102)
        with tempfile.TemporaryDirectory(prefix='blenny-update-dmg-') as staging:
            run('ditto', str(target), str(Path(staging) / 'Blenny.app'))
            archive = root / 'update.dmg'
            run('hdiutil', 'create', '-quiet', '-srcfolder', staging, '-format', 'UDZO', str(archive))
        signer = REPO / '.build/artifacts/sparkle/Sparkle/bin/sign_update'
        signing = ['--ed-key-file', os.environ['BLENNY_SPARKLE_KEY_FILE']] if os.getenv('BLENNY_SPARKLE_KEY_FILE') else ['--account', DOMAIN]
        signature = run(str(signer), *signing, '-p', str(archive)).stdout.decode().strip()
        run(str(signer), *signing, '--verify', str(archive), signature)
        damaged = root / 'tampered.dmg'
        damaged.write_bytes(archive.read_bytes() + b'BLENNY-TAMPER-TEST')
        negative = subprocess.run([str(signer), *signing, '--verify', str(damaged), signature], capture_output=True)
        assert negative.returncode != 0
        results['signature-tamper-rejected'] = True
        for scenario in ('cancel', 'equal', 'older', 'unavailable', 'wrong-signature', 'tampered', 'install'):
            host = root / scenario / 'Blenny.app'
            host.parent.mkdir()
            run('ditto', str(template), str(host))
            configure(host, root, 'cancel' if scenario == 'cancel' else 'install', 101)
            feed = root / 'appcast.xml'
            feed.unlink(missing_ok=True)
            if scenario != 'unavailable':
                build = 101 if scenario == 'equal' else 100 if scenario == 'older' else 102
                package = damaged if scenario == 'tampered' else archive
                sig = base64.b64encode(b'\x00' * 64).decode() if scenario == 'wrong-signature' else signature
                run('python3', str(REPO / 'scripts/create-appcast.py'), '--feed', str(feed),
                    '--archive', str(package), '--version', marketing_version(), '--build', str(build),
                    '--signature', sig, '--download-url', f'http://127.0.0.1:8765/{package.name}',
                    '--release-url', 'https://github.com/f-is-h/Blenny/releases/tag/v' + marketing_version(),
                    '--notes', str(REPO / 'docs/RELEASE_NOTES.md'), '--allow-loopback')
            events = root / 'events.txt'
            events.unlink(missing_ok=True)
            run('open', '-n', '-g', '-W', '-a', str(host), '--args', '-SUEnableAutomaticChecks', 'NO', '-SUAutomaticallyUpdate', 'NO', timeout=65)
            # The installer may relaunch just after the original process exits.
            if scenario == 'install':
                import time
                for _ in range(30):
                    if events.exists() and 'relaunched-target' in events.read_text(): break
                    time.sleep(0.5)
            trace = events.read_text() if events.exists() else ''
            (root / f'{scenario}.events.txt').write_text(trace)
            current_build = plistlib.loads((host / 'Contents/Info.plist').read_bytes())['CFBundleVersion']
            expected = 'cancelled' if scenario == 'cancel' else 'no-update' if scenario in ('equal', 'older') else 'relaunched-target' if scenario == 'install' else 'error:'
            passed = expected in trace and current_build == ('102' if scenario == 'install' else '101')
            if scenario == 'install':
                identity = (REPO / 'Config/SigningIdentity.sha1').read_text().strip().lower()
                run('codesign', '--verify', '--deep', '--strict', '-R=' + f'identifier "{DOMAIN}" and certificate root = H"{identity}"', str(host))
                passed = passed and (host / 'Contents/MacOS/Blenny').read_bytes() == (target / 'Contents/MacOS/Blenny').read_bytes()
                passed = passed and plistlib.loads((host / 'Contents/Info.plist').read_bytes())['SUPublicEDKey'] == plistlib.loads((target / 'Contents/Info.plist').read_bytes())['SUPublicEDKey']
            results[scenario] = {'passed': passed, 'build': current_build, 'events': trace.splitlines()}
            print(f'{scenario}: {"PASS" if passed else "FAIL"}', flush=True)
        after = {str(p.relative_to(state_root)): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in state_root.rglob('*') if p.is_file()} if state_root.exists() else {}
        results['policy-and-recovery-unchanged'] = before == after
    finally:
        server.shutdown()
        server.server_close()
        # Restore only Sparkle keys, keeping any unrelated preference edits made during testing.
        current = preferences()
        for key in list(current):
            if key.startswith('SU'): current.pop(key)
        current.update({k: v for k, v in prior.items() if k.startswith('SU')})
        merged = root / 'preferences-restored.plist'
        merged.write_bytes(plistlib.dumps(current))
        for key in preferences():
            if key.startswith('SU'):
                run('defaults', 'delete', DOMAIN, key)
        run('defaults', 'import', DOMAIN, str(merged))
        results['sparkle-preferences-restored'] = preferences() == current
        (root / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    assert all(v if isinstance(v, bool) else v['passed'] for v in results.values()), 'See results.json'

if __name__ == '__main__':
    main()
