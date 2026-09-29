# Security hardening verification

Review baseline: `5f7d047ff77788dd0e3ae8696c8add6c1a3c4bed` on `main`.
The Git remote is now `https://github.com/Alex-Karpov-878/sayit`.
No changes have been staged, committed, pushed, or installed as an application.

## Changes

- XPC requires the exact bundled peer's code-directory hash in every build,
  including ad-hoc builds. Missing or invalid identities reject connections.
  Both clients and listeners install their requirements unconditionally.
- Local app signing uses hardened runtime and explicitly signs the selected-text
  helper. The main app retains the microphone entitlement needed for explicit
  voice-reference recording. The UI no longer directly links the inference backend.
- HTML extraction uses an inert text scanner, removing the resource-loading HTML
  importer. Numeric and common named character references are decoded as text.
- Hummingbird is pinned to 2.26.0. Both package graphs override the transitive
  yyjson 0.12.0 pin with unmodified vendored 0.13.0 source and recorded hashes.
  No other remote package revisions changed.
- Model downloads validate paths, bounded sizes and digests. The 20 previously
  unhashed bundled files now have SHA-256 hashes of their pinned contents.
  Ordinary remote Git files use Git blob hashes; LFS files use SHA-256.
  Reused staging files, imported copies, and files returned to inference are
  verified. Persisted manifests support rechecking dynamically resolved models.
- Metadata is bounded before parsing; local imports reject oversized metadata
  and symlinks, including hidden ones. Remote Python files are not downloaded.
- The agent blocks unmanaged URLSession requests, including upstream model
  download fallbacks. Managed downloads remain available, including redirects.
- History and recovery-journal persistence are opt-in. Disabling history removes
  the journal and stops new history/audio archives. Existing history is retained
  until explicitly cleared. New data directories and journals have private modes.
- The fork's updater is disabled. Builds require the checked-in package versions;
  plugin validation and the SwiftPM plugin sandbox remain enabled.

## Verification

79 distinct focused Swift Testing tests passed: a 78-test regression run followed
by the three XPC identity tests, including one newly added same-identifier
ad-hoc signing test. The regression run covered text parsing, catalog/path
validation, model installation/import/integrity, download limits, network policy,
settings, history opt-in, persistence, and app settings.

The following filter ran the regression suites with the plugin sandbox enabled:

```sh
swift test --jobs 4 --filter 'ModelManagerTests|CommunityModelResolverTests|ModelFileDownloadDelegateTests|ModelNetworkPolicyTests|BackendSettingsStoreTests|BackendServiceCommandTests/historyRequiresOptIn|BackendPersistenceTests|SecurityRegressionTests|CodeSigningRequirementTests|HistoryPrivacyTests|TextCleanupRegressionTests|TextCleanerTests|ModelCatalogTests|AppSettingsTests'
```

Additional isolated probes using synthetic input:

- The same HTML image fixture that contacted a loopback server before the fix
  produced **zero requests** through the current parser.
- URLSession data and download requests without authorization were blocked;
  authorized requests succeeded. A second probe included a redirect from
  `127.0.0.1` to `localhost` and observed only the expected authorized requests.
- Two different ad-hoc executables signed with the **same identifier** could not
  satisfy each other's code-hash requirement. Neither fixture was executed.
- Both lockfile diffs contained only the expected Hummingbird/yyjson changes.
  Every vendored yyjson file matched its provenance SHA-256.
- Catalog/Info.plist/entitlement validation, shell syntax checks, and
  `git diff --check` passed.

The full SwiftPM test target compiled. The Release bundled-app build stopped
because this Xcode installation lacks the Metal Toolchain. Its actual error was:
`cannot execute tool 'metal' due to missing Metal Toolchain`.
The build therefore does **not** establish a verified, runnable app bundle.
The temporary, exact-revision CudaBuild plugin approval used for that build was
removed afterward. No blanket validation bypass was used.

## Remaining limits

See [SECURITY.md](../SECURITY.md) for the threat model. The main app and selected-text
helper remain unsandboxed; local ad-hoc helpers still lack provisioned App Group
sandbox confinement. Cryptographic peer authentication and hardened runtime
are not substitutes for a sandbox. A separate containment redesign would be
required to remove that architectural trust boundary.

No live model synthesis, end-to-end Accessibility/XPC session, notarization, or
installation was validated. No Accessibility or microphone permission was
requested, and no background service was registered. No audit can establish
that every transitive native dependency is free of malicious or vulnerable code.

Before installation, complete the bundled build with Apple's Metal Toolchain,
then verify bundle signatures and actual helper communication. Xcode identifies
the missing component's download command as
`xcodebuild -downloadComponent MetalToolchain`; it was not run during this work.
