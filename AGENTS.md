# Contributor brief

Voice Keyboard is a SwiftUI macOS menu bar app adapted from MIT-licensed WhisperDictation. It uses local `whisper.cpp` inference. Preserve upstream copyright and license notices when changing code or packaging.

## Where to look

- `README.md`: clean-clone build, first use, permissions, privacy, and current limits.
- `ARCHITECTURE.md`: dictation, insertion, and build paths. Read when changing those paths.
- `VALIDATION.md`: checks already performed and the manual validation sequence. Update it when a claim is verified or a compatibility failure is reproduced.
- `macos_voice_keyboard_codex_plan.md`: product goal, completion criteria, and follow-up work. Read when deciding feature scope.

## Working loop

1. Inspect the affected Swift source and the relevant document above. Identify the behavior and any macOS permission or focus dependency.
2. Make the smallest coherent change. Keep user settings in `AppSettings`; keep model downloads and generated artifacts out of Git.
3. Run `make app` for Swift changes. Run the Xcode test target when Xcode is available and the change touches testable logic. For hotkey, microphone, overlay, or text insertion changes, perform the relevant manual steps in `VALIDATION.md` on a Mac with permissions granted.
4. Record observed behavior and remaining uncertainty in `VALIDATION.md`. Keep public docs free of machine-specific identifiers, personal examples, logs, tokens, and absolute home paths.

The Makefile produces an ad hoc signed local app. `project.yml` is the XcodeGen definition; update both when changing the bundle identity or build inputs. A new bundle identifier requires fresh macOS permission grants and has separate saved settings.
