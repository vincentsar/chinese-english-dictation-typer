# Voice Keyboard

Voice Keyboard is a local macOS menu bar dictation app for English, Mandarin, and mixed speech. Tap a chosen key to start, speak, then tap it again to finish and insert text at the cursor. Hold-to-talk is also available. It is based on the MIT-licensed [WhisperDictation](https://github.com/sam-pop/WhisperDictation) project and uses a pinned [whisper.cpp](https://github.com/ggml-org/whisper.cpp) submodule.

## Build

Requires macOS 14 or later, Command Line Tools, CMake, and an Apple Silicon or Intel Mac. Metal accelerates transcription on supported Macs.

```sh
git clone --recurse-submodules <repository-url>
cd chinese-english-dictation-typer
make whisper
make app
./scripts/download-model.sh small-q5_1
open build/VoiceKeyboard.app
```

For an existing clone, run `git submodule update --init --recursive` first. The model downloads to `~/Library/Application Support/VoiceKeyboard/Models`; onboarding can download a model too. Choose a multilingual model such as `small-q5_1`, rather than one ending in `.en`. Catalog model downloads are checked against pinned SHA-256 hashes after download and again before loading. Model files and build outputs stay outside Git.

For regular use, run `make install` and then `open /Applications/VoiceKeyboard.app`. This copies the **whole** app bundle to Applications. In Finder, you can drag `build/VoiceKeyboard.app` into Applications instead. Do not copy `build/VoiceKeyboard` or `build/VoiceKeyboard.app/Contents/MacOS/VoiceKeyboard` by itself: that leaves out the app metadata and resources, and macOS treats the executable as a different permission target. Turn on **Voice → Settings → General → Launch at login** if desired. Keep one installed copy: macOS permission grants and login items can refer to the specific app bundle you opened.

The local build uses an ad hoc signature. To distribute a signed or notarized copy, configure a bundle identifier you control and sign it with your own Developer ID. The Makefile accepts `BUNDLE_ID=...`; `project.yml` carries the corresponding XcodeGen setting. Changing a bundle identifier makes macOS treat the app as a different app for permissions and saved settings.

## First use

1. Open Voice Keyboard from the menu bar label **Voice**. Allow Microphone access and grant Accessibility access in System Settings → Privacy & Security. Reopen the app if needed.
2. In Settings → General, choose the **Dictation key** that matches your physical keyboard. The default key is Right Option. Modifier remapping can make a physical key report as a different modifier; use the key capture control to identify it.
3. Put the cursor in TextEdit, tap the chosen key, speak, then tap it again. A floating cue shows recording and transcription states; separate chimes mark start and stop. The final transcription is inserted once after you stop. Choose **Hold to talk** in Settings if you prefer press, speak, release.

If a Terminal window only prints `[WhisperBridge] GPU pre-warmed` and the dictation key does nothing, check that you launched `VoiceKeyboard.app`, not a standalone `VoiceKeyboard` executable. That message means the model warmup finished; it does not confirm that the global key or microphone permissions work. Open the **Voice** menu bar item to see model, microphone, Accessibility, and key status. The same panel lets you change language, tap or hold behavior, and speech preview; **Change** opens the key capture control in Settings. After replacing a standalone executable with the app bundle, grant Microphone and Accessibility permission to the app bundle in System Settings.

Settings also provides language, model, input device, cleanup, and insertion choices. Automatic language selection chooses only English or Chinese for each recording. If a short utterance is misheard, choose **English** or **Chinese** in Settings → General. **Speech preview while recording** is off by default because it runs extra recognition passes and can delay the final result; turn it on if seeing provisional text is more useful. The separate experimental **Live dictation** setting inserts phrases when you pause; it requires the voice activity model. Select **Clipboard paste** if a target app rejects Unicode typing. If insertion fails or focus changes during transcription, use **Copy transcription** in the menu bar panel. During final transcription, extra hotkey taps are ignored so the result is preserved.

## Privacy and limits

Recognition runs locally through `whisper.cpp`. The app does not upload microphone audio or save an audio or transcript history by default. Model download is the network operation required during setup. Clipboard paste temporarily exposes the transcript on the shared system pasteboard, where other apps or clipboard managers may read it; the app attempts to restore readable items after pasting, but some rich or promised data may not round-trip. Unicode typing is the default.

Security boundary: Accessibility permission lets the app inspect the focused control and post keyboard events. It checks that the original app, window, and focused control still match before inserting text; if focus cannot be verified, use **Copy transcription**. The app does not execute dictated text as shell commands. Treat downloaded app bundles as code that needs a trusted signature; this source build is ad hoc signed for local use and should be separately signed and notarized before distribution.

The current language selector was added after an English utterance was misidentified as Malay by unrestricted detection. It constrains automatic choice to English or Chinese; a fresh interactive check confirmed English decoding after the change. Mandarin and mixed Mandarin-English speech worked in an earlier interactive TextEdit check. When enabled, the provisional preview can revise itself while recording and may differ from the final text. Accuracy and timing vary with model, microphone, speaker, and app. Secure input fields are outside the supported scope. Some apps may reject simulated typing or paste.

See [ARCHITECTURE.md](ARCHITECTURE.md) for implementation details, [VALIDATION.md](VALIDATION.md) for reproducible checks, and [macos_voice_keyboard_codex_plan.md](macos_voice_keyboard_codex_plan.md) for the product plan. Contributors using coding agents can start with [AGENTS.md](AGENTS.md).
