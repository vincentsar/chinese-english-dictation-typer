import AppKit

final class SoundFeedback {
    private var startSound: NSSound?
    private var stopSound: NSSound?
    private var doneSound: NSSound?

    init() {
        startSound = Self.loadSound("record-start") ?? NSSound(named: "Glass")
        stopSound = Self.loadSound("record-stop") ?? NSSound(named: "Pop")
        doneSound = NSSound(named: "Ping")
        startSound?.volume = 0.9
        stopSound?.volume = 0.9
        doneSound?.volume = 0.65
    }

    private static func loadSound(_ name: String) -> NSSound? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        return NSSound(contentsOf: url, byReference: false)
    }

    var isEnabled: Bool {
        AppSettings.shared.soundFeedbackEnabled
    }

    func playStartSound() {
        guard isEnabled else { return }
        startSound?.stop()
        startSound?.play()
    }

    func playStopSound() {
        guard isEnabled else { return }
        stopSound?.stop()
        stopSound?.play()
    }

    func playDoneSound() {
        guard isEnabled else { return }
        doneSound?.stop()
        doneSound?.play()
    }
}
