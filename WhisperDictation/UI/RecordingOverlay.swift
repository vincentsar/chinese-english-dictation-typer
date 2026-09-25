import AppKit
import SwiftUI

/// A non-activating cue that stays visible while the microphone is recording.
/// It never takes keyboard focus away from the target app.
final class RecordingOverlay {
    private let panel: NSPanel

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 62),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
    }

    func update(_ state: DictationState, preview: String = "", isRecent: Bool = false) {
        guard state != .idle else {
            panel.orderOut(nil)
            return
        }

        let showsPreview = !preview.isEmpty
        let size = NSSize(width: showsPreview ? 440 : 250, height: showsPreview ? 142 : 62)
        panel.setContentSize(size)
        panel.contentView = NSHostingView(rootView: RecordingBadge(
            state: state, preview: preview, isRecent: isRecent
        ))
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let bounds = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: bounds.midX - panel.frame.width / 2,
                y: bounds.maxY - panel.frame.height - 20
            ))
        }
        panel.orderFrontRegardless()
    }
}

private struct RecordingBadge: View {
    let state: DictationState
    let preview: String
    let isRecent: Bool

    private var isRecording: Bool { state == .recording }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 11) {
                Image(systemName: isRecording ? "mic.fill" : "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isRecording ? .red : .orange)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isRecording ? "Recording" : state == .processing ? "Transcribing…" : "Inserting text…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(isRecording ? "Release key to finish" : "Please keep the target app focused")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
                Circle()
                    .fill(isRecording ? Color.red : Color.orange)
                    .frame(width: 8, height: 8)
            }
            if !preview.isEmpty {
                Text(isRecent ? "Recent speech preview" : "Speech preview")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                Text(preview)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: preview.isEmpty ? 250 : 440,
               height: preview.isEmpty ? 62 : 142)
        .background(Color(red: 0.11, green: 0.13, blue: 0.16), in: RoundedRectangle(cornerRadius: 14))
    }
}
