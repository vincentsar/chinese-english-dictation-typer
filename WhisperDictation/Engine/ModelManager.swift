import Foundation
import CryptoKit

final class ModelManager: ObservableObject, @unchecked Sendable {
    static let shared = ModelManager()

    /// Progress (0...1) of in-flight downloads, keyed by model `fileName`. A model
    /// is present here only while it is actively downloading, so each Settings row
    /// shows progress for its own model — not a single shared bar.
    @Published var activeDownloads: [String: Double] = [:]
    /// Latest download failure, surfaced regardless of which tab is visible.
    @Published var downloadError: String?

    /// In-flight download tasks keyed by model `fileName`, for cancellation.
    /// Confined to the main actor (mutated only from `startDownload`/`cancelDownload`).
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    private let fileManager = FileManager.default

    struct ModelInfo: Identifiable {
        let name: String
        let fileName: String
        let size: String
        let speed: String
        let accuracy: String
        let url: URL
        let isQuantized: Bool
        /// Pinned SHA256 of the exact file at `url`, taken from the HuggingFace LFS
        /// pointer (`.../raw/main/<file>` → `oid sha256:`). Verified after download.
        let sha256: String

        /// Generous ceiling for a model transfer. Integrity still comes from sha256.
        var maximumDownloadBytes: Int64 {
            switch fileName {
            case "ggml-base-q5_1.bin": return 120 * 1024 * 1024
            case "ggml-small-q5_1.bin": return 380 * 1024 * 1024
            case "ggml-medium-q5_0.bin": return 1_080 * 1024 * 1024
            case "ggml-small.bin": return 980 * 1024 * 1024
            case "ggml-silero-v5.1.2.bin": return 10 * 1024 * 1024
            default: return 0
            }
        }

        var id: String { fileName }

        /// The id persisted in `AppSettings.selectedModel`: the `fileName` with the
        /// "ggml-" prefix and ".bin" suffix stripped (e.g. "ggml-small-q5_1.bin" →
        /// "small-q5_1"). Single source for the derivation that was hand-inlined in
        /// SettingsView, OnboardingView, and AppSettings.
        var settingsId: String {
            fileName
                .replacingOccurrences(of: "ggml-", with: "")
                .replacingOccurrences(of: ".bin", with: "")
        }

        // Multilingual models are required for English, Mandarin, and mixed speech.
        static let baseQ5 = ModelInfo(
            name: "Base Q5 (Multilingual)", fileName: "ggml-base-q5_1.bin",
            size: "60 MB", speed: "Fastest", accuracy: "Good",
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin")!,
            isQuantized: true,
            sha256: "422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898"
        )
        static let smallQ5 = ModelInfo(
            name: "Small Q5 (Multilingual)", fileName: "ggml-small-q5_1.bin",
            size: "190 MB", speed: "Fast", accuracy: "Better",
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin")!,
            isQuantized: true,
            sha256: "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb"
        )
        static let mediumQ5 = ModelInfo(
            name: "Medium Q5 (Multilingual)", fileName: "ggml-medium-q5_0.bin",
            size: "539 MB", speed: "Balanced", accuracy: "Best",
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q5_0.bin")!,
            isQuantized: true,
            sha256: "19fea4b380c3a618ec4723c3eef2eb785ffba0d0538cf43f8f235e7b3b34220f"
        )
        static let small = ModelInfo(
            name: "Small (Multilingual)", fileName: "ggml-small.bin",
            size: "488 MB", speed: "Balanced", accuracy: "Better",
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
            isQuantized: false,
            sha256: "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b"
        )

        // VAD model
        static let vadSilero = ModelInfo(
            name: "Silero VAD v5", fileName: "ggml-silero-v5.1.2.bin",
            size: "2 MB", speed: "", accuracy: "",
            url: URL(string: "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin")!,
            isQuantized: false,
            sha256: "29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf"
        )

        static let all: [ModelInfo] = [baseQ5, smallQ5, mediumQ5, small]
        static let recommended: [ModelInfo] = [baseQ5, smallQ5, mediumQ5]
    }

    var modelsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("VoiceKeyboard/Models", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var selectedModelInfo: ModelInfo {
        let selectedModel = AppSettings.shared.selectedModel
        return ModelInfo.all.first { $0.settingsId == selectedModel }
            ?? ModelInfo.all.first { $0.fileName.contains(selectedModel) }
            ?? ModelInfo.smallQ5
    }

    /// Recheck the installed bytes immediately before passing a path to whisper.cpp.
    /// A file copied into Application Support or changed after download is untrusted.
    func validatedActiveModelPath() throws -> String? {
        let info = selectedModelInfo
        let url = modelsDirectory.appendingPathComponent(info.fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        try verifyInstalledModel(info, at: url)
        return url.path
    }

    func activeModelPath() -> String? {
        let info = selectedModelInfo
        let path = modelsDirectory.appendingPathComponent(info.fileName).path
        return fileManager.fileExists(atPath: path) ? path : nil
    }

    func validatedVADModelPath() throws -> String? {
        let info = ModelInfo.vadSilero
        let url = modelsDirectory.appendingPathComponent(info.fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        try verifyInstalledModel(info, at: url)
        return url.path
    }

    func vadModelPath() -> String? {
        try? validatedVADModelPath()
    }

    static func verifyInstalledModel(_ model: ModelInfo, at url: URL) throws {
        let actual = try sha256Hex(ofFileAt: url)
        guard actual.caseInsensitiveCompare(model.sha256) == .orderedSame else {
            throw ModelError.installedChecksumMismatch(model.name)
        }
    }

    private func verifyInstalledModel(_ model: ModelInfo, at url: URL) throws {
        try Self.verifyInstalledModel(model, at: url)
    }

    func isModelDownloaded(_ model: ModelInfo) -> Bool {
        fileManager.fileExists(atPath: modelsDirectory.appendingPathComponent(model.fileName).path)
    }

    func downloadedModels() -> [ModelInfo] {
        ModelInfo.all.filter { isModelDownloaded($0) }
    }

    // MARK: - Per-model download state (read by SwiftUI on main)

    func isDownloading(_ model: ModelInfo) -> Bool {
        activeDownloads[model.fileName] != nil
    }

    func downloadProgress(for model: ModelInfo) -> Double? {
        activeDownloads[model.fileName]
    }

    // MARK: - Download control

    // Each (re)start of a download for a key bumps its generation. Only the current
    // generation may write that key's published state, so a cancelled or superseded
    // download can never clobber the UI state of a newer one (cancel → restart race).
    private var downloadGeneration: [String: Int] = [:]

    /// Fire-and-forget download entry point for the UI. Registers a cancellable
    /// task keyed by the model's fileName; ignores duplicate starts.
    @MainActor
    func startDownload(_ model: ModelInfo) {
        let key = model.fileName
        guard downloadTasks[key] == nil else { return }
        let generation = (downloadGeneration[key] ?? 0) + 1
        downloadGeneration[key] = generation
        activeDownloads[key] = 0
        downloadError = nil
        downloadTasks[key] = Task { [weak self] in
            await self?.runDownload(model, generation: generation)
        }
    }

    /// Cancel an in-flight download by model `fileName`.
    @MainActor
    func cancelDownload(name key: String) {
        downloadTasks[key]?.cancel()
        downloadTasks[key] = nil
        // Bump the generation so any late writes from the cancelled task are ignored.
        downloadGeneration[key] = (downloadGeneration[key] ?? 0) + 1
        activeDownloads[key] = nil
    }

    @MainActor
    private func reportProgress(_ progress: Double, key: String, generation: Int) {
        guard downloadGeneration[key] == generation else { return }
        activeDownloads[key] = progress
    }

    @MainActor
    private func finishDownload(key: String, generation: Int, error: String?) {
        guard downloadGeneration[key] == generation else { return }
        activeDownloads[key] = nil
        downloadTasks[key] = nil
        if let error { downloadError = error }
    }

    /// Downloads, verifies (HTTP status + pinned SHA256), and installs a model.
    /// Safe to run twice: the temp file is verified before it replaces any existing
    /// model, and a mismatch throws without touching the installed copy.
    private func runDownload(_ model: ModelInfo, generation: Int) async {
        let key = model.fileName
        let destination = modelsDirectory.appendingPathComponent(model.fileName)
        let delegate = DownloadDelegate(maximumBytes: model.maximumDownloadBytes) { progress in
            Task { @MainActor [weak self] in
                self?.reportProgress(progress, key: key, generation: generation)
            }
        }

        do {
            try Task.checkCancellation()

            let (tempURL, response) = try await URLSession.shared.download(
                from: model.url,
                delegate: delegate
            )

            guard !delegate.exceededLimit else {
                try? fileManager.removeItem(at: tempURL)
                throw ModelError.downloadTooLarge
            }

            // Validate HTTP status before trusting the bytes.
            if let http = response as? HTTPURLResponse, !Self.isAcceptableStatusCode(http.statusCode) {
                try? fileManager.removeItem(at: tempURL)
                throw ModelError.badStatus(http.statusCode)
            }

            // Verify integrity against the pinned hash (streamed, not loaded whole).
            let actual = try Self.sha256Hex(ofFileAt: tempURL)
            guard actual.caseInsensitiveCompare(model.sha256) == .orderedSame else {
                try? fileManager.removeItem(at: tempURL)
                throw ModelError.checksumMismatch(expected: model.sha256, actual: actual)
            }

            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: tempURL, to: destination)

            await finishDownload(key: key, generation: generation, error: nil)
        } catch is CancellationError where delegate.exceededLimit {
            await finishDownload(key: key, generation: generation,
                                 error: ModelError.downloadTooLarge.localizedDescription)
        } catch is CancellationError {
            // cancelDownload() already performed cleanup.
        } catch let urlError as URLError where urlError.code == .cancelled && delegate.exceededLimit {
            await finishDownload(key: key, generation: generation,
                                 error: ModelError.downloadTooLarge.localizedDescription)
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Cancelled mid-transfer — cleanup handled by cancelDownload().
        } catch {
            fputs("[ModelManager] Download failed for \(model.name): \(error)\n", stderr)
            await finishDownload(key: key, generation: generation,
                                 error: "Couldn’t download \(model.name): \(error.localizedDescription)")
        }
    }

    func deleteModel(_ model: ModelInfo) throws {
        let path = modelsDirectory.appendingPathComponent(model.fileName)
        try fileManager.removeItem(at: path)
    }

    // MARK: - Integrity helpers (testable, pure)

    static func isAcceptableStatusCode(_ code: Int) -> Bool {
        (200..<300).contains(code)
    }

    /// Streams the file in 1 MB chunks through SHA256 so large models (up to ~1.5 GB)
    /// are never loaded into memory at once. Returns a lowercase hex digest.
    static func sha256Hex(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

enum ModelError: LocalizedError {
    case badStatus(Int)
    case checksumMismatch(expected: String, actual: String)
    case installedChecksumMismatch(String)
    case downloadTooLarge

    var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            return "Server returned HTTP \(code)."
        case .checksumMismatch:
            return "Downloaded file failed integrity check (checksum mismatch). It was discarded."
        case .installedChecksumMismatch(let name):
            return "The installed \(name) model failed its integrity check. Delete it in Settings and download it again."
        case .downloadTooLarge:
            return "Model download exceeded its size limit and was cancelled."
        }
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let progressHandler: (Double) -> Void
    let maximumBytes: Int64
    private let lock = NSLock()
    private var _exceededLimit = false
    var exceededLimit: Bool {
        lock.lock(); defer { lock.unlock() }
        return _exceededLimit
    }

    init(maximumBytes: Int64, progressHandler: @escaping (Double) -> Void) {
        self.maximumBytes = maximumBytes
        self.progressHandler = progressHandler
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > maximumBytes {
            lock.lock()
            _exceededLimit = true
            lock.unlock()
            downloadTask.cancel()
            return
        }
        guard totalBytesExpectedToWrite > 0 else { return }
        progressHandler(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }
}
