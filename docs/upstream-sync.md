# Upstream sync log

This fork (`Alex-Karpov-878/sayit`) carries its own commits on top of the
original repository (`callebtc/sayit`). Upstream is merged in periodically; this
file records each sync so the next one is faster. Add a new entry at the top of
the log for every sync.

## How to sync

```sh
git remote add upstream https://github.com/callebtc/sayit.git   # once per clone
git fetch upstream --tags
git log --oneline upstream/main..main      # fork-only commits that must survive
git log --oneline main..upstream/main      # incoming upstream commits
git merge upstream/main
```

Conflict handling that has worked:

- `SayIt.xcodeproj/project.pbxproj` is generated. Resolve `project.yml`, then
  run `xcodegen generate --spec project.yml` instead of editing the pbxproj.
- `Package.resolved` (root and `SayIt.xcodeproj/.../swiftpm/`) usually conflicts
  only on `originHash`. Take either side, then run `swift package resolve`;
  SwiftPM recomputes the hash from `Package.swift`.
- `SayItProtocolVersion.current`: when both sides bumped it independently, the
  merged wire format matches neither, so set it one above the larger value and
  update the assertion in `ProtocolRoundTripTests`.
- Test files where both sides appended tests at the same spot are easier to
  resolve from a diff3 rendering (`git merge-file -p --diff3 ours base theirs`)
  because Git's default rendering can split hunks mid-test.
- Keep the fork's hardening (see [security-hardening.md](security-hardening.md))
  whenever upstream rewrites the same code: model-file integrity fields, the
  local `Packages/yyjson` override, the embedded-framework check in
  `Scripts/validate-package-linkage.sh`, and the remote speech routing in
  `SayItBackendService`.

Before compiling anything, vet new or changed dependencies. Building runs
package manifests, macros, and plugins on the host. A cheap first pass:

1. Diff the pins: compare `git show <old-head>:Package.resolved` with the merged
   `Package.resolved` and list new and changed packages.
2. For each package, check its owner, age, stars, and whether it was transferred
   or renamed (`gh api repos/<owner>/<repo>`). Confirm the pinned revision is on
   the default branch (`gh api repos/<r>/compare/<branch>...<sha>` reports
   `behind` or `identical`, not `diverged`). Confirm each version tag still
   points at the pinned commit.
3. Read every new `Package.swift` at the pinned revision for `plugin`, `macro`,
   `binaryTarget` (it must carry a `checksum`), `unsafeFlags`, and code that
   runs in the manifest itself.
4. For low-reputation packages, read the code of the products SayIt actually
   links (`grep 'package: "<name>"' Package.swift`) and scan it for network,
   process, `dlopen`, Keychain, and environment access.

Then verify. Keep SwiftPM's plugin sandbox on, per
[security-hardening.md](security-hardening.md). Upstream's release script
passes `--disable-sandbox`; don't copy that flag:

```sh
swift build --build-system native --build-tests
swift test --build-system native --skip-build
./Scripts/validate-catalog.sh
./Scripts/build-app.sh
```

Pipe build output through `set -o pipefail`. Otherwise a failed build followed
by `swift test --skip-build` runs stale binaries and reports success.

## Log

### 2026-11-18 — merged upstream v0.2.3

- Upstream head: `caaba90` (tag `v0.2.3`, "Prepare Say It 0.2.3 release",
  2026-11-12). Brought in 34 commits covering v0.2.0 to v0.2.3: Phonon voices,
  Drama 3 via `swift-tts`, Qwen3-TTS clone reference limits, 3x reading speed,
  CLI audio export, MLX cache cap, landing page redesign.
- Fork head before merge: `eafabbf`. Fork-only commits kept: `dd339db` (IPC,
  model loading, and build hardening), `1863009` (list speech cleanup),
  `37bc139` (selection toggles, main window, remote speech), `eafabbf` (local
  signing and background service packaging).
- Merge base: `5f7d047` (PR #29). The next sync's merge base will be this
  merge commit.

Conflict resolutions:

| File | Resolution |
| --- | --- |
| `Package.swift`, `project.yml` | Kept fork's local `yyjson` package and upstream's `swift-transformers`, `swift-tts`, `mlx-swift-lm` |
| `SayItProtocolVersion.swift` | Fork was 9, upstream 10, merged to **11** |
| `ModelFileDescriptor.swift` | Kept both fork's `gitBlobSHA1` and upstream's `source` |
| `CommunityModelResolver.swift` | Upstream's adaptive playback for `fish_drama3`, fork's `files: manifest` |
| `SayItBackendService.swift` | Fork's `RoutingSpeechSynthesizer` (local + OpenAI-compatible remote) |
| `SynthesisActor.swift` | Upstream's voice-preparation timing |
| `VoicesSettingsView.swift` | Fork's accessibility modifiers plus upstream's `.disabled` and two-argument `onChange` |
| `validate-package-linkage.sh` | Both fork's embedded-framework check and upstream's duplicate-module checks |
| `prepare-release-dmg.sh` | Upstream's `--build-system native --disable-sandbox` flags |
| Test files | Kept both sides' new tests; upstream's sparse placeholder voice files in the backend fixture |

Behavior decision: both sides changed list cleanup. Upstream (`86cb908`) now
speaks right arrows as "to" ("Text→speech" becomes "Text to speech"); the fork's
tests asserted arrows were preserved. Upstream's behavior was kept and the fork's
four arrow-preservation tests were dropped. The fork's nested-list offsets test
was kept, with its expectation updated to `牛乳 to コップ`.
`TextCleanupRegressionTests.swift` was rebuilt as upstream's file plus that one
test. Both sides' arrow tests had survived outside the conflict hunks, and
Swift Testing reports duplicate test names as
`thrown expression type 'any Error' cannot be converted to error type 'Never'`.

Test adaptations. Upstream tests assume defaults that the fork's hardening
changed, so the tests were updated, not the hardening:

- The fork's `ServiceFixture` defaults history to off, so `silentSpeechExport`,
  `failedSilentSpeech`, and `canceledSilentSpeech` opt in with
  `historyEnabled: true`.
- `resolvesRemotePhononModel` stubbed a 16-character revision. The fork accepts
  only 40-hex immutable revisions, so the stub now uses one.
- `SpeechQueuePolicyTests.unfinishedJobsDoNotStartAfterServiceRestart` was
  already failing on the fork before this merge: it predates the history
  opt-in, and the recovery journal is opt-in. It now opts in.
- A mock sine generator in `BackendServiceCommandTests` hit the type checker's
  time limit under load and now has explicit types.

Dependency vetting (new or changed pins):

| Package | Pin | Verdict |
| --- | --- | --- |
| `arraypress/swift-tts` | 3.2.1 `338c0bc` | One maintainer, 2 stars, created 2026-07. Manifest has no plugins or binaries. SayIt links only `DramaTTS` and `SpeechSynthesizer` (4.8k lines). Read and scanned: no network, process, `dlopen`, Keychain, or environment access. Drama 3 weights carry the non-commercial Fish Audio Community License. |
| `arraypress/swift-stdout-silencer` | 0.2.0 `2931ff6` | 1 star, created 2026-10-28. Pulled in by swift-tts's OmniVoice target only; not linked into SayIt. Manifest is trivial. |
| `FluidInference/FluidAudio` | 0.15.2 `7f963cd` | Established org (3.3k stars). Used by swift-tts Kokoro/Pocket targets only; not linked into SayIt. |
| `microsoft/onnxruntime-swift-package-manager` | 1.24.2 `b7fb7f7` | Official. Binary targets from `download.onnxruntime.ai` with pinned SHA-256 checksums. Not linked into SayIt. |
| `Blaizzy/mlx-audio-swift` | `bf14ae0` to `624fd54` | Repo transferred to `Neywa-Labs`; original maintainer is still top contributor. All 16 new commits are GitHub-verified and by known contributors. Keychain code is only in `Examples/`. **Its PocketTTS loader now resolves unknown voice names as local `.safetensors` paths or `hf://` URLs** (see fixes). |
| `ml-explore/mlx-swift` | 0.31.6 to `ac4ae9a` | Official. `CudaBuild` plugin is `#if os(Linux)` only. |
| `ml-explore/mlx-swift-lm` | 3.31.4 to `ee673d6` | Official. Contains a swift-syntax macro target. |

All pinned commits are on their repositories' default branches and all version
tags match the lockfile. The merged lockfile equals upstream's except for
`ibireme/yyjson`, which the fork intentionally replaces with `Packages/yyjson`.

Security review of the merged tree (no critical or high findings). Fixes made
during the merge:

- **History opt-in regression** (`SayItBackendService.synthesizeWithoutPlayback`).
  Upstream's playback-less path (`sayit speak --no-play`) wrote an m4a into
  `historyAudio` even with history disabled, leaving an orphaned private audio
  file. It now applies the same guards as `archiveCompletedRequest`. Regression
  test: `silentSpeechRequiresHistoryOptIn`.
- **Voice names reaching model loaders as paths or URLs**
  (`SayItBackendService.isPresetVoiceName`). Community `pocket_tts` models have
  no catalogued voices, so preset names went to the loader unvalidated, letting
  an authenticated client load any local `.safetensors` file or fetch an
  `hf://` file. Preset names may no longer contain `/ \ : ~ .`. Regression test:
  `presetVoiceNamesAreLabels`.

Accepted and documented rather than changed:

- Upstream removed the App Sandbox from the `sayit` CLI (`Config/SayItCLI.entitlements`)
  so `--output` can write to user-chosen paths. Recorded in
  [security-hardening.md](security-hardening.md). Export writes are still
  no-overwrite and staged (`CLIExportDestination`).
- Known limitation: with history disabled (the fork default),
  `sayit speak --no-play --output` fails with `history.not_found`, because export
  reads from history. Making it work without history would need an export path
  that bypasses the archive.
