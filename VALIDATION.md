# Validation

This file records checks that have been performed and gives contributors a repeatable manual check. Results are observations, not a guarantee of accuracy on every microphone or target app.

## Completed checks

- An installed `/Applications/VoiceKeyboard` was observed to be a bare Mach-O executable, while the build output is `VoiceKeyboard.app`. `codesign --display --verbose=4` reported `Identifier=VoiceKeyboard-arm64` and `Info.plist=not bound` for the standalone executable; the app bundle's `Info.plist` declares `org.voicekeyboard.VoiceKeyboard`. This reproduces the installation mismatch behind the terminal-only launch report. The standalone process was stopped, the complete app bundle was installed under `/Applications/VoiceKeyboard.app`, and its process launched. The prior bare executable was moved to Trash. A live hotkey check with this bundle remains outstanding.
- `make whisper` and `make app` built a local app with Command Line Tools. `codesign --verify --deep --strict build/VoiceKeyboard.app` passed.
- The multilingual `small-q5_1` model loaded locally and completed warmup inference. The model download matched its pinned SHA-256 hash.
- A menu bar launch, Accessibility event tap, microphone capture, recording overlay, distinct start and stop sounds, and insertion into TextEdit worked in an interactive check.
- A physical key remapped to Right Control produced macOS key code 62. Configuring that key code enabled hold-to-dictate. This is why the app needs a visible key selection and capture control.
- Interactive Mandarin and mixed Mandarin-English dictation inserted text in TextEdit. The mixed utterance contained English terms inside a Mandarin sentence; its content is intentionally omitted from this public log.
- Unrestricted automatic language detection later rendered an English utterance as Malay. The app now limits automatic selection to English or Chinese and offers fixed modes. Interactive English succeeded after this change; Mandarin and mixed microphone checks should be repeated with the new selector.
- After a fresh launch with the saved Right Control key and Accessibility access, two interactive English recording cycles selected English and completed transcription. The user confirmed the recording cue responded again.
- In a later interactive check, tap-to-toggle started and stopped recording, provisional text appeared in the overlay during speech, and the final transcript inserted once after processing. After a punctuation cleanup change, the user confirmed that a Mandarin sentence inserted without an extra English period.
- With speech preview off by default, a subsequent live check completed final transcription without preview inference passes. No controlled latency comparison has been recorded.
- A local `whisper.cpp` API check of the constrained selection chose English for synthetic English (`en` probability 0.996), Chinese for synthetic Mandarin (`zh` probability 0.996), and Chinese for a mixed sample (`zh` probability 0.986). Explicit decode produced the expected English, Mandarin, and mixed terms. This checks the same language APIs used by the app, but does not replace an interactive app test.
- Full Xcode was unavailable in the initial build environment, so the Xcode unit-test target was not run. The app builds without test results from that target.

## Synthetic speech check

macOS `say` generated audio, converted to 16 kHz mono WAV, then transcribed by the pinned `whisper.cpp` CLI with automatic language detection and the multilingual small Q5 model. This checks model loading and decoding; it does not assess human speech quality or app insertion.

| Sample | Prompt | Observed transcript |
| --- | --- | --- |
| English | “Please send me the updated revenue report tomorrow morning.” | “Please send me the updated revenue report tomorrow morning.” |
| Mandarin | “请你明天早上把最新的营收报告发给我。” | “请你明天早上把最新的营收报告发给我。” |
| Mixed | “这个客户的 conversion rate 大概是 twenty five percent，我们下星期再 follow up。” | “这个客户的conversion rate大概是25%,我们下星期再follow up。” with the app's initial prompt |

The mixed transcript preserves English terms but can change spacing and punctuation. The app also converts traditional characters to simplified Chinese after transcription.

## Manual check for a new build

1. Build and launch the app using the README instructions. Grant Microphone and Accessibility permissions for that bundle identifier.
2. Choose a dictation key in Settings → General. Use the capture control with a remapped modifier, verify the displayed key matches what macOS reports, and confirm it works without restarting the app.
3. Focus a blank TextEdit document. Tap the chosen key, speak an English sentence, and tap it again. Confirm the recording cue and start sound appear on the first tap, the stop sound occurs on the second, and text appears after transcription. Tap once during processing to confirm it does not cancel the final result. Repeat in optional Hold to talk mode by holding and releasing the key.
4. Repeat with Mandarin and a mixed-language sentence. Check punctuation, spaces, and simplified Chinese output. Confirm English stays English with **English + Chinese (automatic)**; try the fixed **English** and **Chinese** modes on short phrases.
   Check that Chinese `。！？；：` is never followed by an added English period.
5. Confirm the default **Speech preview while recording** switch is off and ordinary dictation still works. Turn it on, then speak for several seconds and confirm the floating preview updates while recording. After the stop tap, confirm only the final transcription is inserted once and it can differ from the preview. Try a longer sentence so the preview shows recent speech without blocking final insertion.
6. Try Clipboard paste in an app that rejects Unicode typing. Check that the target text arrives and existing clipboard content is restored when possible.
7. Start recording in one field, switch focus to another field or window in the same app, then stop. Confirm no text is inserted and the transcript remains available through **Copy transcription**.
8. Replace a test model file with altered bytes, then reload it. Confirm the app reports an integrity error before loading the native parser. Restore the original model afterward.
9. Change focus before transcription completes. Confirm that the app avoids typing into the wrong app and that **Copy transcription** recovers the result.

Release-to-text latency, accessibility across other apps, and clipboard behavior still need broader measurements.
