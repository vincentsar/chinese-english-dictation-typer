# Voice Keyboard product plan

## Goal

A person can place the cursor in a normal macOS text field, tap a configurable key, speak English, Mandarin, or both, tap again, and receive text in that field. Hold-to-talk is optional. Transcription runs locally. The first version is a menu bar app; a full macOS input source is a separate future project.

## Current implementation

The native Swift app is adapted from MIT-licensed [WhisperDictation](https://github.com/sam-pop/WhisperDictation). It uses a pinned `whisper.cpp` submodule, multilingual Whisper models, language selection constrained to English and Chinese, simplified Chinese conversion, a configurable global push-to-talk key, a provisional recording preview, start and stop chimes, Unicode event insertion, optional clipboard paste, and a copy-transcript recovery action. Model binaries are downloaded by users and verified against pinned hashes. See [ARCHITECTURE.md](ARCHITECTURE.md) for the code path and [VALIDATION.md](VALIDATION.md) for checks performed.

A live TextEdit check confirmed microphone capture, visual and sound feedback, and insertion. Mandarin and mixed speech worked. A remapped physical modifier demonstrated the need for an easy key selection flow.

## V1 completion criteria

- **Setup:** A new user can build or install the app, download a multilingual model, grant permissions, and choose a dictation key without editing configuration files.
- **Dictation key:** One tap starts capture, the next stops it, and the interface shows each state. A provisional preview is optional and off by default for lower latency. Hold-to-talk remains optional. Key selection works when physical modifier positions are remapped by macOS.
- **Recognition:** English, Mandarin, and mixed-language utterances are transcribed locally. User-selected vocabulary and cleanup can improve output without silently changing factual content.
- **Insertion:** Text goes to the app focused when recording began. If focus changes or insertion fails, the transcript remains available to copy. Unicode event and clipboard paste paths are documented and checked in representative apps.
- **Privacy:** Audio stays on device during dictation. The app requests only permissions needed for the feature and explains when model download uses the network.
- **Distribution:** The source builds from a clean clone, license notices are retained, binaries and models stay outside Git, and any distributed binary is signed and notarized with a publisher-owned bundle identifier.

## Next work

1. Verify the dictation key picker with a remapped physical modifier and check that the selected key works immediately.
2. Check the constrained language selector with real English, Mandarin, and mixed speech; measure release-to-text latency and error patterns across supported models.
3. Check Unicode insertion and clipboard paste in common editors, browsers, messaging apps, and controls with secure input. Record reproducible failures in [VALIDATION.md](VALIDATION.md).
4. Improve permission guidance and recovery after a model or microphone error.
5. Prepare signed release artifacts and a simple installation path for people who do not build from source.

## Later research

- Accessibility value insertion where keyboard events and paste cannot reach a standard editable control.
- A true macOS InputMethodKit input source if the menu bar app cannot meet measured compatibility needs.
- Optional voice commands and multiple speaking modes once the core dictation flow is stable.
