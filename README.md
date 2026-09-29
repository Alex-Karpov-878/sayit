# Say It

This fork includes local-build and supply-chain hardening. Read [SECURITY.md](SECURITY.md)
for the protections, changed defaults, and remaining trust boundaries before installing.

Private, local text-to-speech for Apple silicon Macs. Say It turns selected or
copied text into speech with open models running through
[MLX Audio](https://github.com/Blaizzy/mlx-audio)—your text and generated audio
stay on your Mac by default. Optional remote TTS sends text only to the endpoint
you enable in Advanced settings.

<table>
  <tr>
    <td width="46%"><img src="public/resources/player.png" alt="Say It menu-bar player"></td>
    <td width="54%"><img src="public/resources/models.png" alt="Say It model library"></td>
  </tr>
</table>

<p align="center">
  <a href="public/resources/introducing.mp4">Watch the introduction</a>
</p>

## Highlights

- **Speak from anywhere.** Select text in another app and press the configurable
  selection hotkey, choose **Services → Say It**, or use the separate clipboard
  hotkey. Press the selection shortcut again with the same text or no selection
  to pause/resume; select different text to begin another reading.
- **A native menu-bar player.** Read the clipboard, pause, seek, change playback
  speed, follow the spoken text, and revisit history without leaving your
  current app.
- **Open models from Hugging Face.** Download supported MLX models in the app,
  including [Qwen3 TTS](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit),
  [Kokoro](https://huggingface.co/mlx-community/Kokoro-82M-bf16),
  [Chatterbox](https://huggingface.co/mlx-community/Chatterbox-TTS-fp16), and
  [OmniVoice](https://huggingface.co/mlx-community/OmniVoice). Compatible
  community models can be added by Hugging Face repository ID.
- **Create voices.** Models expose the features they support, from built-in
  voices and voice descriptions to random voice discovery and voice cloning.
- **Efficient model loading.** Only one model is kept in memory, and it is
  automatically unloaded after a configurable period of inactivity (ten
  minutes by default).
- **Local by design.** Synthesis works offline after model download. There is no
  analytics or passive clipboard monitoring. Remote inference is optional and
  disabled by default.
- **Hear your coding agent work.** The bundled
  [Say It agent skill](skills/sayit/SKILL.md) provides live, hands-free spoken
  progress updates while an agent works.

## Clone your voice

For models with voice-cloning support, Voice Studio guides you through recording
or importing a clean reference sample, checks its quality, and saves it as a
reusable voice profile. You stay in control of the recording: voice samples and
profiles remain on your Mac, and cloning runs locally.

Only clone a voice when you have the speaker's permission.

## Getting started

Say It requires macOS 15 or later on an Apple silicon Mac.

1. Install and launch Say It.
2. Choose and download a model during onboarding.
3. Optionally allow Accessibility access, select text in another app, and press
   **Control–Option–S**. You can also copy text and press
   **Control–Option–V**, or choose **Services → Say It**.

Both shortcuts can be changed in Settings. Say It queries the current selection
or reads clipboard text only when you explicitly invoke the matching action.

### Open the app window

Open Say It from Spotlight, Finder, or the Dock to show its main window. The
sidebar provides access to General, Voices, Models, Speech, and the other
settings. Reopening the app brings back the same window and selected section.
Closing the window keeps Say It running so its reading shortcuts remain
available. Use **Say It → Quit** to stop the app.

The menu-bar **Settings…** button and **Command–comma** open the same window.
Local builds are named **Say It Local** and keep their settings and model
library separate from the official app.

### Terminal

The app includes a `sayit` CLI for speech, playback, models, voices, and
automation:

```sh
sayit "Read this aloud"
printf 'Read standard input' | sayit
sayit status
sayit pause
sayit resume
sayit skill path
```

Run `sayit --help` to see all commands and options.

### Coding-agent voice mode

Ask a compatible coding agent to load the skill file returned by:

```sh
sayit skill path
```

A good generic prompt is:

```text
Load the Say It skill and use it for live spoken updates. Run `sayit skill path` to get the skill path.
```

The [Say It agent skill](skills/sayit/SKILL.md) narrates meaningful progress
and the final handoff without blocking the underlying task, while keeping
concise written updates for details you may need to copy. Resolve the path
again after upgrading Say It so the guidance stays aligned with the installed
CLI.

## Architecture

The native SwiftUI frontend is separate from a per-user backend service that
owns model downloads, synthesis, playback, and history. The app and CLI talk to
that service over XPC. A narrowly scoped accessibility helper retrieves the
frontmost app's selection only when requested. An optional, token-protected HTTP
server exposes the same synthesis engine to other local apps through a
versioned REST API bound to `127.0.0.1`. Advanced settings can instead send the text you choose to speak (and any API
key) to a user-configured OpenAI-compatible TTS endpoint on another machine.
Returned audio plays on the Mac, speech history remains stored only on the Mac,
and local MLX remains the default when that option is off.

The synthesis layer is built primarily on
[MLX Audio](https://github.com/Blaizzy/mlx-audio), with the native Swift
integration provided by
[mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift).

## Build from source

Install Xcode with Swift 6.2 or later and
[XcodeGen](https://github.com/yonaskolb/XcodeGen), then run:

```sh
brew install xcodegen
./Scripts/build-app.sh
```

Package versions are fixed by the checked-in lockfiles. On a new machine,
Xcode may ask to approve MLX's `CudaBuild` plugin. Review and approve only the
pinned package in Xcode, then rerun the build; plugin validation stays enabled.
The reviewed plugin does no CUDA work on macOS. If dependencies have not yet
been resolved, open the generated project in Xcode and resolve the locked graph.

Local builds compile independent targets and Swift source batches in parallel,
using all available logical CPUs by default. Set `SAYIT_BUILD_JOBS` to cap the
number of concurrent build operations. Signed release builds keep whole-module
optimization; set `SAYIT_SWIFT_COMPILATION_MODE=wholemodule` to reproduce that
behavior in an ad-hoc local build.

Local builds are written to `Build/DerivedData-Local`; signed builds use
`Build/DerivedData-Release`. The build stops if the app at its selected output
path is still running, so quit Say It before rebuilding it.

For a stable Accessibility grant across Debug rebuilds, set
`SAYIT_SELECTION_SIGN_IDENTITY` to the same Apple Development signing identity
used for the app. The build does not select a certificate from your keychain
automatically.

Tests run with `swift test`.

Run launch, reopen, and onboarding UI checks with `./Scripts/test-windows.sh`
on a macOS desktop with Xcode UI testing enabled.

## More screenshots

[Voice cloning](public/resources/cloning.png)

## License

Say It is available under the [MIT License](LICENSE). Models are distributed
under their own licenses; review the model card before downloading or using one.

### Software updates

Automatic and manual Sparkle updates are disabled in this fork so an upstream
release cannot replace the security changes. Rebuild from reviewed source for
updates. History saving is also off by default; enable it explicitly in History
settings if desired. Existing saved history is retained until cleared.

### Reviewed build plugins

If Xcode asks to trust a pinned build plugin, review that plugin before allowing
it. For a headless build after review, use
`SAYIT_TRUST_REVIEWED_PLUGINS=1 ./Scripts/build-app.sh`. The same opt-in applies
to `Scripts/test-windows.sh`. This opt-in bypasses
Xcode's plugin fingerprint prompt; plugin execution remains sandboxed and
dependency versions remain locked.

### Local signing and UI tests

The hardened app needs a valid Apple signing identity shared by its executable
and embedded frameworks. An ad-hoc build can compile and pass signature-seal
checks, but macOS library validation can reject it at launch. Do not disable
library validation to bypass this requirement. For window tests, set
`SAYIT_SIGN_IDENTITY` to your installed signing identity before running
`Scripts/test-windows.sh`; the script builds with local identifiers and signs
the app and test runner with that identity.
