import SwiftUI

struct MenuBarView: View {
    let engine: DictationEngine
    @ObservedObject private var permissions = PermissionManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @Environment(\.openWindow) private var openWindow
    private let permissionTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            readinessSection
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // Alerts (permissions / errors)
            if !permissions.allPermissionsGranted || engine.modelLoadError != nil || engine.transcriptionError != nil || modelManager.downloadError != nil {
                alertsSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            // Last transcription
            if !engine.lastTranscription.isEmpty {
                transcriptionSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            Divider()
                .padding(.horizontal, 12)

            controlsSection
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 12)

            // Actions
            VStack(spacing: 2) {
                MenuButton(title: "Settings...", icon: "gearshape", shortcut: ",") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                MenuButton(title: "Quit Voice Keyboard", icon: "power", shortcut: "Q") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // Version
            Text("v\(Bundle.main.appVersion)")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 6)
        }
        .frame(width: 320)
        .onAppear { permissions.checkPermissions() }
        .onReceive(permissionTimer) { _ in
            if !permissions.allPermissionsGranted { permissions.checkPermissions() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            // Status orb
            ZStack {
                Circle()
                    .fill(statusGradient)
                    .frame(width: 36, height: 36)

                if engine.state == .recording {
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 2)
                        .frame(width: 44, height: 44)
                }

                Image(systemName: statusIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Voice Keyboard")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    // Model badge — short friendly name
                    if engine.isModelLoaded {
                        Text(modelShortName)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.3)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.blue.opacity(0.12)))
                            .foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }

    // MARK: - Alerts

    private var readinessSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Setup")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ReadinessRow(title: "Model", detail: engine.isModelLoaded ? "Loaded" : engine.modelLoadError == nil ? "Loading…" : "Needs attention", ready: engine.isModelLoaded)
            ReadinessRow(title: "Microphone", detail: permissions.microphoneGranted ? "Allowed" : "Allow access", ready: permissions.microphoneGranted)
            ReadinessRow(title: "Accessibility", detail: permissions.accessibilityGranted ? "Allowed" : "Allow access", ready: permissions.accessibilityGranted)
            HStack {
                Image(systemName: engine.isEventTapActive ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(engine.isEventTapActive ? .green : .orange)
                    .frame(width: 15)
                Text("Dictation key")
                Spacer()
                Text(engine.isEventTapActive ? "Active" : "Inactive")
                    .foregroundStyle(.secondary)
                Button("\(hotkeyLabel) · Change") { showSettings() }
                    .buttonStyle(.link)
            }
            .font(.system(size: 11))
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dictation")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker("Language", selection: $settings.languageMode) {
                Text("English + Chinese").tag(AppSettings.LanguageMode.englishChinese)
                Text("English").tag(AppSettings.LanguageMode.english)
                Text("Chinese").tag(AppSettings.LanguageMode.chinese)
            }
            Picker("Key action", selection: $settings.hotkeyMode) {
                Text("Tap once, tap again").tag(AppSettings.HotkeyMode.toggle)
                Text("Hold to talk").tag(AppSettings.HotkeyMode.pushToTalk)
            }
            Toggle("Speech preview", isOn: $settings.speechPreviewEnabled)
        }
        .font(.system(size: 12))
    }

    private func showSettings() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
    }

    private var alertsSection: some View {
        VStack(spacing: 6) {
            if !permissions.microphoneGranted {
                AlertRow(icon: "mic.slash.fill", text: "Microphone access needed", color: .orange) {
                    permissions.requestMicrophone()
                }
            }
            if !permissions.accessibilityGranted {
                AlertRow(icon: "hand.raised.fill", text: "Accessibility access needed", color: .orange) {
                    permissions.openAccessibilitySettings()
                }
            }
            if let error = engine.modelLoadError {
                AlertRow(icon: "exclamationmark.triangle.fill", text: error, color: .red) {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            if let error = engine.transcriptionError {
                AlertRow(icon: "waveform.badge.exclamationmark", text: error, color: .orange) {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            // Download failures must surface even when Settings (Model tab) isn't open.
            // Cleared automatically when the user retries (startDownload resets it).
            if let error = modelManager.downloadError {
                AlertRow(icon: "exclamationmark.arrow.triangle.2.circlepath", text: error, color: .orange) {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    // MARK: - Last Transcription

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last transcription")
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.3)
                .foregroundStyle(.tertiary)

            Text(engine.lastTranscription)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary.opacity(0.5))
                )

            Button("Copy transcription") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(engine.lastTranscription, forType: .string)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
        }
    }

    // MARK: - Status Helpers

    private var statusIcon: String {
        switch engine.state {
        case .idle: "waveform"
        case .recording: "mic.fill"
        case .processing: "brain.head.profile.fill"
        case .typing: "text.cursor"
        }
    }

    private var statusText: String {
        switch engine.state {
        case .idle:
            if engine.modelLoadError != nil { "Model needs attention" }
            else if !engine.isModelLoaded { "Loading model…" }
            else if !permissions.microphoneGranted || !permissions.accessibilityGranted || !engine.isEventTapActive { "Finish setup to dictate" }
            else if settings.hotkeyMode == .toggle { "Ready — tap \(hotkeyLabel) to dictate" }
            else { "Ready — hold \(hotkeyLabel) to dictate" }
        case .recording:
            settings.hotkeyMode == .toggle
                ? "Listening — tap \(hotkeyLabel) to stop"
                : "Listening — release \(hotkeyLabel) to stop"
        case .processing: "Transcribing..."
        case .typing: "Typing..."
        }
    }

    private var statusDotColor: Color {
        switch engine.state {
        case .idle: engine.isModelLoaded && permissions.allPermissionsGranted && engine.isEventTapActive ? .green : .orange
        case .recording: .red
        case .processing: .orange
        case .typing: .blue
        }
    }

    private var statusGradient: LinearGradient {
        let colors: [Color] = switch engine.state {
        case .idle: engine.isModelLoaded && permissions.allPermissionsGranted && engine.isEventTapActive
            ? [.green.opacity(0.8), .green.opacity(0.5)]
            : [.orange.opacity(0.8), .orange.opacity(0.5)]
        case .recording: [.red.opacity(0.9), .red.opacity(0.6)]
        case .processing: [.orange.opacity(0.8), .orange.opacity(0.5)]
        case .typing: [.blue.opacity(0.8), .blue.opacity(0.5)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var modelShortName: String {
        let m = settings.selectedModel
        // "base-q5_1" → "Base Q5", "small" → "Small"
        let base = m.split(separator: ".").first.map(String.init) ?? m
        let isQuantized = m.contains("q5") || m.contains("q8")
        return base.capitalized + (isQuantized ? " Q5" : "")
    }

    private var hotkeyLabel: String {
        KeyCodeNames.shortLabel(for: settings.hotkeyKeyCode)
    }
}

private struct ReadinessRow: View {
    let title: String
    let detail: String
    let ready: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ready ? .green : .orange)
                .frame(width: 15)
            Text(title)
            Spacer()
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
    }
}

// MARK: - Alert Row

private struct AlertRow: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(color.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Menu Button

private struct MenuButton: View {
    let title: String
    let icon: String
    let shortcut: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                Text("⌘\(shortcut)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuButtonStyle())
    }
}

private struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.blue.opacity(0.8) : Color.clear)
            )
            .foregroundStyle(configuration.isPressed ? .white : .primary)
    }
}
