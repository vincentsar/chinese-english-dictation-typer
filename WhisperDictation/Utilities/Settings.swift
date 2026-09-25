import Foundation

final class AppSettings: ObservableObject, @unchecked Sendable {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Hotkey Mode

    enum HotkeyMode: String { case pushToTalk, toggle }
    enum InsertionMode: String { case unicode, paste }
    enum LanguageMode: String, Sendable { case englishChinese, english, chinese }

    // MARK: - Keys

    private enum Key: String {
        case hotkeyKeyCode
        case hotkeyMode
        case toggleHoldDuration
        case selectedModel
        case soundFeedbackEnabled
        case speechPreviewEnabled
        case vocabularyPrompt
        case launchAtLogin
        case minimumRecordingDuration
        case grammarCorrectionEnabled
        case selectedAudioDeviceUID
        case numberConversionEnabled
        case customTerms
        case hasCompletedOnboarding
        case liveDictationEnabled
        case insertionMode
        case languageMode
    }

    // MARK: - Properties

    var hotkeyKeyCode: Int {
        get { defaults.object(forKey: Key.hotkeyKeyCode.rawValue) as? Int ?? 61 } // 61 = right Option
        set { defaults.set(newValue, forKey: Key.hotkeyKeyCode.rawValue); objectWillChange.send() }
    }

    var hotkeyMode: HotkeyMode {
        get {
            let raw = defaults.string(forKey: Key.hotkeyMode.rawValue) ?? HotkeyMode.toggle.rawValue
            return HotkeyMode(rawValue: raw) ?? .toggle
        }
        set { defaults.set(newValue.rawValue, forKey: Key.hotkeyMode.rawValue); objectWillChange.send() }
    }

    /// Seconds the hotkey must be held to trigger start/stop in toggle mode.
    /// Clamped on write to the slider range so out-of-band programmatic writes can't break the UI.
    var toggleHoldDuration: Double {
        get {
            let stored = defaults.object(forKey: Key.toggleHoldDuration.rawValue) as? Double ?? 1.5
            // Clamp on read too: an out-of-band raw value (older build, corrupt
            // domain) must not escape the slider range and break the UI/logic.
            return max(0.5, min(3.0, stored))
        }
        set {
            let clamped = max(0.5, min(3.0, newValue))
            defaults.set(clamped, forKey: Key.toggleHoldDuration.rawValue)
            objectWillChange.send()
        }
    }

    var selectedModel: String {
        get {
            let stored = defaults.string(forKey: Key.selectedModel.rawValue) ?? "small-q5_1"
            // Fall back to the default if the stored id doesn't correspond to any
            // catalog model (see ModelInfo.settingsId). Guards against a stale id left
            // behind after the catalog changes.
            let isKnown = ModelManager.ModelInfo.all.contains { $0.settingsId == stored }
            return isKnown ? stored : "small-q5_1"
        }
        set { defaults.set(newValue, forKey: Key.selectedModel.rawValue); objectWillChange.send() }
    }

    var soundFeedbackEnabled: Bool {
        get { defaults.object(forKey: Key.soundFeedbackEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.soundFeedbackEnabled.rawValue); objectWillChange.send() }
    }

    /// Display provisional transcription while recording. Defaults off so
    /// standard dictation spends its inference work on the final result.
    var speechPreviewEnabled: Bool {
        get { defaults.bool(forKey: Key.speechPreviewEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.speechPreviewEnabled.rawValue); objectWillChange.send() }
    }

    var insertionMode: InsertionMode {
        get {
            let raw = defaults.string(forKey: Key.insertionMode.rawValue) ?? InsertionMode.unicode.rawValue
            return InsertionMode(rawValue: raw) ?? .unicode
        }
        set { defaults.set(newValue.rawValue, forKey: Key.insertionMode.rawValue); objectWillChange.send() }
    }

    var languageMode: LanguageMode {
        get {
            let raw = defaults.string(forKey: Key.languageMode.rawValue) ?? LanguageMode.englishChinese.rawValue
            return LanguageMode(rawValue: raw) ?? .englishChinese
        }
        set { defaults.set(newValue.rawValue, forKey: Key.languageMode.rawValue); objectWillChange.send() }
    }

    var vocabularyPrompt: String {
        get {
            defaults.string(forKey: Key.vocabularyPrompt.rawValue) ?? Self.defaultVocabularyPrompt
        }
        set { defaults.set(newValue, forKey: Key.vocabularyPrompt.rawValue); objectWillChange.send() }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin.rawValue) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin.rawValue); objectWillChange.send() }
    }

    /// Whether the user has seen (or been auto-skipped past) first-launch onboarding.
    /// Defaults to false so a fresh install shows the flow once; existing users who
    /// already have a model on disk are marked complete at launch without ever seeing it.
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding.rawValue); objectWillChange.send() }
    }

    var minimumRecordingDuration: Double {
        get {
            let stored = defaults.object(forKey: Key.minimumRecordingDuration.rawValue) as? Double ?? 0.3
            // Clamp on read: a nonsensical raw value must not gate every recording.
            return max(0.0, min(5.0, stored))
        }
        set { defaults.set(newValue, forKey: Key.minimumRecordingDuration.rawValue); objectWillChange.send() }
    }

    var grammarCorrectionEnabled: Bool {
        get { defaults.object(forKey: Key.grammarCorrectionEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.grammarCorrectionEnabled.rawValue); objectWillChange.send() }
    }

    var numberConversionEnabled: Bool {
        get { defaults.object(forKey: Key.numberConversionEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.numberConversionEnabled.rawValue); objectWillChange.send() }
    }

    /// Live dictation (commit-on-pause): type each phrase when the speaker
    /// pauses instead of everything at stop. Default false. Stores intent —
    /// the engine additionally requires the VAD model on disk per session.
    var liveDictationEnabled: Bool {
        get { defaults.bool(forKey: Key.liveDictationEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.liveDictationEnabled.rawValue); objectWillChange.send() }
    }

    /// Maximum number of custom vocabulary terms. Mirrors the UI cap; enforced here
    /// so no write path (import, programmatic) can exceed the whisper prompt budget.
    static let maxCustomTerms = 100

    var customTerms: [String] {
        get { defaults.stringArray(forKey: Key.customTerms.rawValue) ?? [] }
        set {
            let capped = Array(newValue.prefix(Self.maxCustomTerms))
            defaults.set(capped, forKey: Key.customTerms.rawValue); objectWillChange.send()
        }
    }

    func addCustomTerm(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var terms = customTerms
        // Avoid duplicates (case-insensitive)
        if !terms.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            terms.append(trimmed)
            customTerms = terms
        }
    }

    func removeCustomTerm(_ term: String) {
        customTerms = customTerms.filter { $0 != term }
    }

    /// nil means "use system default"
    var selectedAudioDeviceUID: String? {
        get { defaults.string(forKey: Key.selectedAudioDeviceUID.rawValue) }
        set { defaults.set(newValue, forKey: Key.selectedAudioDeviceUID.rawValue); objectWillChange.send() }
    }

    // MARK: - Default Vocabulary Prompt

    // Keep the default prompt short so it does not drown out language detection.
    // Users can add names and domain terms in Settings.
    static let defaultVocabularyPrompt = """
        简体中文和 English 混合口述。常用词：conversion rate, revenue report, follow up, API, OpenAI, ChatGPT, Codex, MLX, WhisperKit。
        """

}
