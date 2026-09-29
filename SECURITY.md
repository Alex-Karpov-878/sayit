# Security and Privacy

## Fork hardening

This fork disables the upstream Sparkle updater. Updates must be rebuilt from
reviewed source until a fork-owned signed feed, signing identity and update key
are deliberately configured. Changing only the remote does not change updater
trust. `SayItUpdatesEnabled` defaults to false in `project.yml`.

XPC clients and servers authenticate the code-directory hashes of the exact
executables bundled together and require the same user. This applies to local
ad-hoc builds too. Missing, unsigned or invalid peer executables fail closed.
Build and sign the complete bundle before running it; loose `swift run` helpers
are intentionally not trusted. Rebuild/restart all peers together after changes.
Local builds use hardened runtime. This does not protect against an attacker
who can replace the whole app on disk or already control the user's account.

Clipboard HTML is scanned as text, without WebKit or attributed-string HTML
rendering. Images, stylesheets and other embedded resources are not fetched.
RTF retains its separate AppKit importer.

The yyjson 0.13.0 source override in `Packages/yyjson` fixes
[GHSA-f4vc-345x-4mvm](https://github.com/ibireme/yyjson/security/advisories/GHSA-f4vc-345x-4mvm).
The transitive swift-transformers dependency still requests vulnerable 0.12.0;
keep the override until that dependency is fixed. Its exact upstream revision
and file hashes are recorded in `Packages/yyjson/PROVENANCE.md`. Both dependency
graphs pin Hummingbird 2.26.0. Package plugins retain their execution sandbox;
the build script requires the checked-in resolved versions.

Managed model downloads use immutable revisions and enforce expected byte
limits and digests. Bundled model files have SHA-256 checksums; remote ordinary
Git files use their Git blob SHA-1 identity, and LFS files use SHA-256. Reused
staging files and model files handed to inference are verified again. Metadata
and non-weight files are capped at 128 MiB; individual weight archives at 32 GiB.
Local imports hash their files, reject symlinks, and verify the staged copy.
Models installed by older versions without a file manifest may need reinstalling.

The speech agent blocks unmanaged URLSession HTTP requests before constructing
the inference backend. Reviewed model-manager and community-resolution requests
explicitly opt in. This blocks upstream mutable-revision fallback downloads;
a missing dependency fails with an install/repair error instead. It is not a
network sandbox for malicious native code using other networking APIs.

## Privacy and remaining trust boundaries

Saving speech history is **off by default**, including when reading older
settings without this preference. Opting in saves cleaned text, recovery jobs
and audio locally, without application-level encryption. Turning it off removes
the recovery journal and stops new history/audio archives. Existing saved
history remains until Clear History is used. Audio needed for current playback
can still exist in temporary storage; this is not a secure-erasure guarantee.
New application data directories are owner-only; recovery journals are mode 0600.

The main app and selected-text helper are **not sandboxed**. The Developer ID
speech agent/CLI have App Sandbox entitlements; the default local ad-hoc build
still lacks their provisioned App Group sandbox setup. Hardened runtime and XPC
authentication do not provide filesystem confinement. The UI no longer links
the inference backend directly, but it still runs native third-party code.
Do not interpret this source review as proof that every dependency is benign.

Accessibility access is optional and belongs to the dedicated selected-text
helper. Grant it only if that shortcut is needed. Microphone access is used for
explicit voice-reference recording. Hugging Face tokens are kept in Keychain.
Model hashes establish expected bytes, not the trustworthiness of their author
or freedom from native parser bugs. Review community models before importing.

The optional HTTP API is off by default and binds to `127.0.0.1`. It validates
Host, uses bearer tokens, limits request sizes and rates, and does not enable
permissive CORS. API-token administration is not exposed over HTTP. Diagnostic
events exclude source text and credentials.

Report security issues privately to this fork's repository owner. Never include
credentials, private speech, or identifying machine details in public reports.

## Optional remote speech

Remote OpenAI-compatible TTS is disabled by default. Enabling it in Advanced
settings sends text to the configured endpoint when speech is requested. API
keys remain in Keychain, separate from settings and diagnostics. Local synthesis
remains the default. Remote requests are explicitly authorized through the
reviewed network policy; unmanaged model downloads remain blocked.

HTTPS is required except for loopback and local-network endpoints. Redirects
are refused. Changing endpoints does not forward the previous endpoint's key.
Remote audio responses and decoded PCM are bounded before playback.
