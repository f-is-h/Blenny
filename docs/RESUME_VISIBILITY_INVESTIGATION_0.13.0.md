# Resume visibility and application host identity

## Result and boundary

On the inspected macOS 27.0 build `26A428`, Betta's location-dependent failure
has a concrete explanation: MenuBarAgent's sandbox cannot read the desktop or
development-build executable directory. AppKit's external-process bundle
resolver checks that access before reading bundle information. A denied check
returns nil; the resulting status-item identity is then rejected by assessment
after Blenny Resume. The process itself can still have a valid Bundle ID.

This supersedes the unresolved path-versus-registration hypothesis in the
[0.13.0 spike](TECH_SPIKE_0.13.0.md#owner-operated-desktop-copy-contrast). It does
not establish a universal rule that every non-Applications location fails on
every macOS installation. Directory access is a necessary part of this inspected
identity route, not a complete physical-visibility test.

## Identity-to-filter chain

Read-only inspection of the installed Apple binaries reconstructs this flow:

```text
status-item scene client audit token
    -> BSProcessHandle.processHandleForAuditToken
    -> BSProcessHandle.bundleIdentifier
    -> external-client executable path from proc_pidpath_audittoken
    -> executable directory must pass the caller's sandbox file-read-data check
    -> bundle information must supply a usable CFBundleIdentifier
    -> stored NSStatusItemHost.bundleIdentifier
    -> MenuBarCore.StatusItemHost.sourceHost.bundleIdentifier
    -> ComponentStatusItemClientElement.bundleIdentifier
    -> active assessment: reject nil, otherwise check allowed bundle membership
    -> layout and presentation
```

MenuBarAgent is the reader in this route. Giving Betta or Blenny access to the
same directory does not give MenuBarAgent that access. Its code signature
includes the app-sandbox entitlement and a process-info exception, consistent
with being able to resolve the client executable yet fail the directory read.

The `No server elements for status item: ...` log calls the same host identity
accessor used when constructing the assessment-filtered client element. This
is now a statically traced relationship, rather than only a correlation between
two logs. The optional string is converted to the typed BundleIdentifier or the
nil discriminator `0xc`, then stored in the seventh client-element field. The
existing filter checks that discriminator before membership. No debugger was
attached to or code injected into MenuBarAgent.

Research locators below are unslid addresses for this exact installed build;
they are never called as product constants. MenuBarAgent arm64e UUID remains
`9E3A0BA9-0E78-3C4E-B0E7-8B2BC1BD09C8`.

| Evidence | Locator |
| --- | --- |
| Log reads host identity before formatting the optional | MenuBarAgent `0x100283c34`, `0x100283cb8` |
| Source-host optional Bundle ID accessor | MenuBarAgent `0x100287f98` |
| Client-element conversion, nil discriminator and seventh-field store | MenuBarAgent `0x100283f54`–`0x100283f8c`, `0x10028408c`–`0x1002840a4` |
| Client-element field metadata | MenuBarAgent `0x1003d4b88` |
| Assessment nil rejection | MenuBarAgent `0x10000e558`–`0x10000e570` |
| Host constructor obtains audit token, process handle and Bundle ID | AppKit `0x185d84738`–`0x185d84808` |
| Process-handle Bundle ID resolution | BaseBoard `0x188ed5bb8` |
| Audit-token Bundle ID resolution | BaseBoard `0x188ebb98c` |
| Audit-token executable path uses `proc_pidpath_audittoken` | BaseBoard `0x188ebb7d4`, call at `0x188ebb854` |
| Executable bundle-info lookup rejects a denied directory read | BaseBoard `0x188ebb2f8`, guard at `0x188ebb334`–`0x188ebb338` |
| Sandbox helper checks the current reader PID, `file-read-data`, path filter 1 | BaseBoard `0x188ebac14`–`0x188ebac70` |

The bundle-info lookup does not contain a hard-coded `/Applications` test. Its
first gate is the reader's path access. The executable is obtained from the
client's audit token, not selected from competing Launch Services app paths.
For a same-process query, BaseBoard instead uses `NSBundle.mainBundle`; testing
only an application's own identity would miss the external-reader failure.

AppKit stores the optional identity when constructing the status-item host.
BaseBoard's inspected process/audit-token accessors also cache their resolved
value. Therefore moving a package does not establish that an already existing
host will recompute its identity. Quitting the affected application and launching
the installed copy creates a fresh host; another Resume alone is not such a
refresh.

## Read-only permission checks and owned-copy control

The [Debug-only original probe](../Research/0.13.0/README.md) checks the same
operation and flags against the exact running MenuBarAgent PID. Its current
`SANDBOX_CHECK_NO_REPORT` value is `1073741824`; the path filter is 1. No sandbox
policy, assertion, application preference or status-item registration is written.

For the actual Betta paths, the result was:

| Executable directory | MenuBarAgent read check | Existing physical evidence |
| --- | --- | --- |
| `/Applications/Betta.app/Contents/MacOS` | Permitted, result 0 | Owner confirmed visibility after Resume |
| `$HOME/Desktop/Betta.app/Contents/MacOS` | Denied, result 1 | Owner confirmed disappearance after Resume |
| Development `dist/Betta.app/Contents/MacOS` | Denied, result 1 | Earlier owner-observed absence and nil host log |

The prior desktop-to-Applications contrast used the same owner-attested package
and the same continuously running MenuBarAgent. The desktop scene connected with
`xyz.fi5h.betta`, was admitted with `isAllowed: true`, and had an existing
bundle-scoped tracking row, yet its host log was nil. Thus a stale tracking row
is not needed to explain the failure; a valid registration cannot bypass the
subsequent path-read guard or nil-identity filter.

A second experiment used four simultaneous copies of one owned, disposable
probe package. All executable hashes matched; all Info.plist hashes matched;
all four direct executable launches read the same non-nil own Bundle ID. No
`open` or Launch Services registration API was used and no status item was
created. MenuBarAgent's query while these actual directories existed returned:

| Owned probe location | MenuBarAgent read check |
| --- | --- |
| Global `/Applications` | Permitted |
| User `$HOME/Applications` | Denied |
| Repository LocalData | Denied |
| New `/private/tmp` directory | Denied |

This isolates a path-dependent reader restriction without relying on a malformed
Bundle ID, different package contents, a menu-extra registration cache or reboot.
The identical Bundle IDs do not change these access results. All four created
packages and the temporary parent were removed, with absence verified. A fresh
read of the native tracking preference found no record for the probe's exact ID.

## Full Disk Access follow-up

On September 28 the owner enabled Full Disk Access for Blenny. A read-only
Accessibility observation of System Settings independently confirmed the Blenny
toggle was on. Blenny's running process differed from the earlier investigation;
MenuBarAgent was still the same process as before the grant. The exact order of
the permission change and Blenny relaunch was not independently timed. No
permission toggle, application restart or system-process restart was performed
by this investigation.

A fresh probe compared the three actual Betta executable directories with the
saved pre-grant query. All results were unchanged: global Applications permitted,
desktop denied, development `dist` denied. This confirms that granting Blenny
Full Disk Access did not change the identified MenuBarAgent read guard. The
reader in the identity route is MenuBarAgent, not the Blenny assertion client.

Full Disk Access and App Sandbox are different permission mechanisms. Apple's
[Developer Technical Support explanation](https://developer.apple.com/forums/thread/124895)
states that a sandboxed app still needs the appropriate sandbox access even
when privacy access is granted. That general distinction supports the current
observation; it is not a claim that an arbitrary privacy grant can remove
MenuBarAgent's sandbox restrictions.

Granting Full Disk Access to MenuBarAgent itself was not attempted and is not
established as a repair. The configured Blenny grant was observed, but reads of
unrelated protected user data were not used to test its effective access. No new
desktop Betta relaunch or physical visibility test was performed in this
follow-up. The permission-check result is enough to show that the previously
identified first gate remains denied.

## Conditions and limits

For an ordinary application status item to survive the inspected Resume filter,
its scene must exist and request presentation, native admission must permit it,
its host must acquire a non-nil usable Bundle ID, and that ID must be in the
active assessment allow-list. Successful filtering still does not prove visible
pixels: the application can remove its item, and layout/overflow can clip it.
For this external identity route, executable-path resolution, reader directory
access and valid bundle information are prerequisites for the host ID.

Blenny includes accepted Visible and observed running unmanaged bundles in its
baseline, adds Revealable bundles during reveal, and excludes Hidden bundles in
both states. Changing a desktop Betta to Visible or excluding it from policy
writes cannot exempt a nil host from the global assessment filter.

Now Playing is a separate failure: its Control Center client element has no
assessment system identifier on this build. It does not use this application
Bundle ID branch. Relocating Betta or resolving an application ID does not fix
Now Playing; the evidence and restoration-only disposition remain in the spike.

Validation used Xcode 27.0 `27A266a` and the macOS 27.0 SDK. The probe compiled
with warnings as errors, the owned-copy comparison completed, malformed/stale or
non-MenuBarAgent readers were refused, and compilation without `DEBUG=1` failed
as intended. This investigation changes research and documentation only; it
does not rebuild, install, modify or complete the product version.

Not performed: new physical menu-extra trials at user Applications or temporary
paths, a Finder/`open` versus direct-launch physical matrix, Launch Services cache
deletion or re-registration, changes to MenuBarAgent permissions, or tests on
other OS builds. The static first gate and kernel access queries made those
mutations unnecessary to identify Betta's observed failure. No manual owner
action is currently required for that diagnosis.
