# Architecture

Voice Keyboard adapts the native SwiftUI menu bar shell of [WhisperDictation](https://github.com/sam-pop/WhisperDictation) under the retained MIT license. A pinned `whisper.cpp` submodule performs local transcription. The adaptation offers multilingual Whisper models, English/Chinese language selection, and simplified Chinese conversion. Upstream notices remain in `LICENSE` and the submodule.

## Dictation path

`HotkeyMonitor` observes the configured key through a `CGEvent` tap. `DictationEngine` defaults to a tap-to-toggle state machine: key down starts recording when idle and stops it when recording; additional presses during final processing are ignored. Hold-to-talk is optional. The engine controls `AudioCapture`, passes 16 kHz mono samples to `WhisperBridge`, applies optional `TextCorrector` cleanup, and sends the result to `TextInjector`. The bridge keeps the selected model in memory and uses Metal when available. Automatic language mode computes Whisper language probabilities but chooses only English or Chinese before decoding; fixed English and Chinese modes skip that detection pass. The hotkey and language mode are saved in app settings and may be changed from the UI.

`RecordingOverlay` shows a non-activating panel while recording and transcribing. Optional speech preview is off by default. When enabled in standard dictation, a timer takes bounded snapshots of recent microphone audio and decodes one provisional preview at a time. The preview stays in the panel; stopping cancels preview work, decodes the complete capture, and inserts the final text once. The experimental Live dictation mode instead inserts voice activity chunks on pauses. `SoundFeedback` plays bundled start and stop chimes. Because the panel does not take keyboard focus, dictated text can go to the original app.

`TextInjector` emits Unicode keyboard events by default. It captures the frontmost app and focused Accessibility element when recording begins, along with the focused window when available, then checks them before queued insertion. If focus cannot be verified, insertion fails and the latest transcript remains available in the menu bar panel. Clipboard paste is an alternate setting for controls that reject Unicode events: it snapshots readable pasteboard items, simulates Command-V, and restores that snapshot only if the pasteboard still contains the app's write. Other apps and clipboard managers can read the transcript while it is on the shared pasteboard; some rich pasteboard representations may not round-trip. Secure fields remain subject to macOS protection.

`TextCorrector` normalizes punctuation after transcription. It respects existing Chinese and English punctuation and chooses `。` for an unpunctuated Chinese ending or `.` for an English ending. The live phrase path uses the same sentence-ending rule when it finishes a session.

## Security boundary

The app has no shell-command or script execution path for dictated text. Accessibility is required for the global event tap, focused-control check, and keyboard injection; Microphone is required for capture. Installed model hashes are checked before passing files to the native parser, and downloads have size limits. Clipboard restoration leaves newer user clipboard contents alone. This is a user-space app without a sandbox in the local Makefile build, so release binaries should use a publisher-owned bundle identifier, Developer ID signing, hardened runtime, notarization, and a review of any additional entitlements.

## Build paths

`make whisper` builds universal `whisper.cpp` static libraries; `make app` builds an ad hoc signed local app with Command Line Tools. `project.yml` is the XcodeGen project definition for Xcode builds and unit tests. Keep bundle identifiers consistent between the Makefile and XcodeGen settings. Model binaries and generated build artifacts are excluded from Git.

## Follow-up work

- Measure latency and recognition quality across supported models and microphones.
- Check insertion behavior in a representative set of apps and controls.
- Evaluate accessibility value insertion only where existing paths fail.
- Prepare a separately signed and notarized release if distributing app binaries.
