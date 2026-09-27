# 0.12.0 signing and Sparkle update integration

Status: app integration, a durable local code-signing identity, and an
EdDSA-signed update archive are verified locally. Local key exports now exist
at the repository root and are excluded from Git. The owner reports keeping
the PKCS#12 export as a SafeInCloud attachment; its restore/import has not
been tested by request. Independent Sparkle-key recovery, a public HTTPS feed,
and an installed Sparkle update are still pending.
This is **not published or accepted as a completed update path**. This document
does not close the separate bookmark, reboot, Apply or Undo gates in the
[permission investigation](SIGNING_PERMISSION_CONTINUITY_0.12.0.md).

## Two independent signing keys

Blenny's durable local route uses a dedicated long-lived self-signed Code
Signing identity for its `.app` and the embedded Sparkle framework. Keep the
same identity, bundle ID
`xyz.fi5h.blenny`, entitlements and installed path across updates. The first
move from a previous signer needs its own permission onboarding. Never reuse
Usage4Claude's private signing identity or the disposable A/B test identity.

Sparkle uses a separate Ed25519 key under Keychain account
`xyz.fi5h.blenny` to sign update archives. Its public key is in
`Config/Info.plist`; it is not a code-signing certificate. The private Sparkle
key and the code-signing private key must be retained and backed up securely
outside Git. The Sparkle key can be exported with `generate_keys --account
xyz.fi5h.blenny -x <private-file>` only to an owner-controlled secure location;
that export is an unencrypted private seed and must not be left in a build
directory or uploaded as a CI artifact. Export the code-signing identity from
Keychain Access as an encrypted PKCS#12 backup under an owner-controlled
password. Do not put either key, backup, password, or signing material in Git.
On this host, the owner-requested local exports are
`/Blenny-CodeSigning.p12` and `/Blenny-Sparkle-Ed25519.key` relative to the
repository root. Both have mode `0600` and are excluded by the `*.p12` and
`*.key` suffix rules in `.gitignore`. The
Sparkle `.key` file is **unencrypted**; make an encrypted copy in separate
owner-controlled storage before treating these local files as a recovery plan.
Signing the same existing update ZIP with the exported file and the Keychain
account yielded identical 88-character EdDSA signatures. This verifies that
the exported Sparkle key matches the active signing key without importing it.

The pinned Sparkle version and binary checksum come from its Swift Package
Manager manifest. The manually packaged framework and its helpers are copied
and signed inside out; the app is signed last. The packaged executable retains
only a relative framework runpath, and `codesign --verify --deep --strict`
must pass. This app is not sandboxed, so Sparkle's sandbox-only XPC entitlements
are not added. The app starts its updater only when its bundle has a valid HTTPS
`SUFeedURL` and the 32-byte public EdDSA key. Automatic checks and automatic
installation are disabled; Settings and the App menu offer manual checks when
the feed is configured. A local unapplied Board draft blocks an update check
and normal termination, so an update cannot silently abandon that draft. The
owner must apply or discard it deliberately before continuing.

## Durable identity setup

The owner created `Blenny-CodeSigning` in the login Keychain, separate from
Usage4Claude and the disposable A/B identity. It has a 4096-bit RSA key,
Digital Signature key usage, Code Signing extended key usage and a certificate
valid from 2026-09-26 to 2036-09-23. Its public SHA-1 identity hash is
`A8B5D4CB304878A53B7B76C139572F414D70EC28`. Signed builds 22–27 use
the designated requirement `identifier "xyz.fi5h.blenny" and certificate root
= H"a8b5d4cb304878a53b7b76c139572f414d70ec28"`. An identical
certificate name does not prove that a later package uses the same key. The
owner entered an export password in Keychain Access and the PKCS#12 file was
created at the requested repository root. A blank-password OpenSSL check
failed, confirming that the file is password-protected. Import into an isolated
keychain has **not** been verified at the owner's request. The owner reports
storing the PKCS#12 file as a SafeInCloud attachment; this is an owner-managed
backup, not a tested restore. Do not rely on the local export alone for future
builds. Do not
add this self-signed certificate to the system trust roots merely to make a
local signature appear Apple verified.

`Config/SigningIdentity.sha1` contains only the public certificate fingerprint.
Both feed-enabled packaging commands require that exact root in the bundle's
designated requirement. A planned key rotation must update this public pin and
repeat first-signer permission onboarding; changing only the certificate name
would not retain Device Control continuity.

## Build and prepare an update

Set `DEVELOPER_DIR` to Xcode 27. `BLENNY_CODE_SIGN_IDENTITY` should name the
exact persistent Blenny identity, preferably by SHA-1 identity hash. The
build script defaults to ad-hoc only for development builds. Set
`BLENNY_UPDATE_FEED_URL` to the final public HTTPS `appcast.xml` URL when
building an update-capable package; a private repository URL or placeholder
is not a usable production feed. The build number must increase for each
published update.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
BLENNY_CODE_SIGN_IDENTITY=<Blenny identity hash> \
BLENNY_UPDATE_FEED_URL=https://<public-host>/appcast.xml \
./scripts/build-app.sh debug
./scripts/prepare-sparkle-update.sh \
  <signed-Blenny.app> https://<public-host>/downloads/ <ignored-output-directory>
```

`prepare-sparkle-update.sh` checks the installed identity shape, bundle ID,
public update key, feed URL and strict nested signatures. It creates an
immutable ZIP archive and uses Sparkle's `generate_appcast` with the dedicated
Keychain account to write an EdDSA-signed enclosure. It does **not** publish
the archive or appcast. Verify the generated appcast, HTTPS download URLs,
version and archive signature before any publication. Preserve old archives
and feed history when a real distribution channel is established; the current
single-output invocation is only a first release candidate preparation flow.

## Local verification on 2026-09-26

| Case | Observed result | Limit |
| --- | --- | --- |
| Signed Debug Builds 22 and 23 with placeholder HTTPS feed | Different CDHashes, identical certificate-bound designated requirement and entitlements; strict nested `codesign` verification passes. | `example.invalid` is a packaging test address, not a working feed. |
| Signed Release Build 26 with placeholder HTTPS feed | The pinned certificate requirement, relative Sparkle framework runpath and strict nested signature checks pass. | This is an offline packaging check, not Release ordering acceptance or a distributable update. |
| Sparkle package from Build 23 | `generate_appcast` emitted one EdDSA-signed enclosure; `sign_update --verify` passed; the ZIP-extracted app passed strict nested code-signature verification. | No network download or Sparkle installation occurred. |
| Root Sparkle private-key export | Signing the same existing ZIP via `--ed-key-file` and via Keychain account `xyz.fi5h.blenny` succeeded with identical signatures. The public key still matches `Config/Info.plist`. | This validates the exported seed, not an off-host backup or restore. |
| Build 17 disposable signer to durable Build 24 at `/Applications/Blenny.app` | The new process initially reported Device Control denied; after removing the old entry and granting the installed app, Settings reported granted. Its normal-launch file/API/file read agreed on the same 33-key ordering table as before replacement. | First-signer onboarding required user action. The saved bookmark remained stale. |
| Durable Build 24 to 25 at the same path | Build 25 reported Device Control granted without another grant. The Board populated and each of its three ordering reads agreed. | Nineteen existing ordering-position values changed between these captures without Blenny Apply. The cause is unconfirmed, so full order continuity failed this run. |
| Build 25 process restart and same-build overwrite | Device Control stayed granted without user action, and the 33-key table digest stayed identical across both cases. | No macOS reboot or Sparkle-delivered replacement was tested. |
| Build 25 to 27 same-signer manual upgrade | Distinct CDHashes with the same designated requirement, Bundle ID, entitlement and path; strict nested signatures pass. Device Control remained granted without regrant. The entire 33-key ordering table and private Blenny app-state files stayed unchanged. | The saved bookmark remained stale. This manual replacement does not test Sparkle delivery or macOS reboot. |
| Build 27 local controls before owner Apply | Within-area sort and Visible→Revealable→Hidden drafts worked, and Discard returned both to the saved layout without changing the 33-key table or private app-state files. | Native drag and Apply were later exercised by the owner; Undo remains untested. |
| Build 27 normal-quit guard with an unapplied sort draft | Quit was cancelled, the app and draft remained visible, and the explicit apply-or-discard warning appeared. Discard cleared the draft; the full 33-key table and private Blenny app-state files remained unchanged. | This verifies normal quit only; an actual Sparkle installation and its draft handoff remain untested. |
| Owner native drag and Apply on Build 27 | The owner reported both worked normally. A read-only diagnostic after Apply found 33 keys, three agreeing read sources and four changed application-position values. The recovery receipt recorded `applied` with exact configuration verified, and Device Control remained granted. | The app could not independently verify all physical positions, the bookmark remains stale, and Undo was not tested. This is a manual interaction result, not a Sparkle-installed update. |
| Build 25 local controls | Within-area sort and Visible→Revealable→Hidden drafts appeared; Discard removed them and left the table digest unchanged. | Native drag, Apply and Undo were not exercised on Build 25. |

Normal termination of Build 17 changed only its saved `managementEnabled`
field from `true` to `false`; its policy maps stayed identical. Build 24 and 25
therefore opened with management stopped. This is a lifecycle state change,
not evidence of a TCC or signing failure. The 19-value preference change is
present in direct-file, container API, and second file reads, so it is not
only a presentation-cache mismatch. The existing stale bookmark predates the
durable identity and did not prevent these normal-launch reads. All raw app
state and preference diagnostics remain in ignored `LocalData/`.

## Required acceptance before enabling a public feed

- Use two successive Blenny builds with the **same durable** code-signing
  identity and distinct build numbers. Compare their designated requirements,
  nested signatures, bundle ID, entitlements and path. Do not infer continuity
  from a common certificate name.
- Verify the first identity transition separately from same-identity updates.
  Record Device Control, exact-file bookmark and independent ordering reads in
  the normal LaunchServices context.
- Host the appcast and update archive over HTTPS; use an isolated test install
  to exercise Sparkle's check, signature verification, replacement and relaunch.
  Check that the updated executable is the expected build and that the running
  app still has the required permissions. A generated archive and XML file are
  not an installed-update pass.
- Preserve the accepted live ordering and Undo receipt. Do not use Apply as a
  signing or updater workaround. The intermittently unstable Undo path remains
  a separate deferred issue.
- Self-signed signing does not provide Developer ID, Apple notarization or a
  default-Gatekeeper distribution pass. A future public release must decide
  how to handle that independent gate.

References: [Sparkle basic setup](https://sparkle-project.org/documentation/),
[programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/),
[manual framework signing](https://sparkle-project.org/documentation/sandboxing/#code-signing),
and [update publication](https://sparkle-project.org/documentation/publishing/).
