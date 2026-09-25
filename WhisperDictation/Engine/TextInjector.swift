import AppKit
import CoreGraphics
import Foundation

/// @unchecked Sendable: `insertionFailed` is confined to the serial typing queue.
/// The event source is immutable after initialization.
final class TextInjector: @unchecked Sendable {
    /// AX elements identify the control (or window) focused when recording starts.
    /// They are only queried again on the serial typing queue.
    struct Target: @unchecked Sendable {
        let pid: pid_t
        let focusedElement: AXUIElement
        let focusedWindow: AXUIElement?
    }

    private let source: CGEventSource?
    private let typingQueue = DispatchQueue(label: "com.whisperdictation.typing", qos: .userInteractive)
    // Accessed only on typingQueue. Reset before each recording begins.
    private var insertionFailed = false

    init() {
        source = CGEventSource(stateID: .hidSystemState)
    }

    static func captureTarget() -> Target? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let element = attribute(kAXFocusedUIElementAttribute as CFString, of: app) else {
            return nil
        }
        let window = attribute(kAXFocusedWindowAttribute as CFString, of: app)
        return Target(pid: pid, focusedElement: element, focusedWindow: window)
    }

    private static func attribute(_ name: CFString, of app: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, name, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func targetIsFocused(_ target: Target?) -> Bool {
        guard let target,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid else { return false }
        let app = AXUIElementCreateApplication(target.pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let current = attribute(kAXFocusedUIElementAttribute as CFString, of: app),
              CFEqual(current, target.focusedElement) else { return false }
        if let original = target.focusedWindow {
            guard let current = attribute(kAXFocusedWindowAttribute as CFString, of: app),
                  CFEqual(current, original) else { return false }
        }
        return true
    }

    /// Enqueue `text` to be typed at the current cursor position via CGEvent.
    /// Returns immediately — the actual typing happens asynchronously on a dedicated
    /// serial queue, so callers (e.g. the whisper decode thread delivering segments)
    /// are never blocked by the per-chunk `Thread.sleep`. The serial queue preserves
    /// submission order, so segments are typed in the order they were decoded.
    /// Call `flush()` to wait for all enqueued typing to finish.
    func beginSession() {
        typingQueue.async { self.insertionFailed = false }
    }

    func type(text: String, target: Target?, mode: AppSettings.InsertionMode = .unicode) {
        typingQueue.async { [self] in
            if mode == .paste {
                paste(text: text, target: target)
                return
            }
            let chunks = Self.chunks(of: Array(text.utf16))

            for (i, chunk) in chunks.enumerated() {
                // Never send a delayed transcript into a different frontmost app.
                guard Self.targetIsFocused(target) else {
                    insertionFailed = true
                    return
                }
                guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                      let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                    insertionFailed = true
                    return
                }

                chunk.withUnsafeBufferPointer { ptr in
                    keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: ptr.baseAddress)
                    keyUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: ptr.baseAddress)
                }

                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)

                if i < chunks.count - 1 {
                    Thread.sleep(forTimeInterval: 0.005)
                }
            }
        }
    }

    /// A compatibility path for controls that ignore Unicode CGEvents. Clone every
    /// readable pasteboard representation before replacing it. Restore only while
    /// our own pasteboard write is still current, so a user copy is never overwritten.
    private func paste(text: String, target: Target?) {
        guard Self.targetIsFocused(target) else {
            insertionFailed = true
            return
        }

        let transaction: ([NSPasteboardItem], Int)? = DispatchQueue.main.sync {
            let board = NSPasteboard.general
            var saved: [NSPasteboardItem] = []
            for item in board.pasteboardItems ?? [] {
                let clone = NSPasteboardItem()
                for type in item.types {
                    guard let data = item.data(forType: type), clone.setData(data, forType: type) else {
                        return nil
                    }
                }
                saved.append(clone)
            }
            board.clearContents()
            guard board.setString(text, forType: .string) else {
                if !saved.isEmpty { _ = board.writeObjects(saved) }
                return nil
            }
            return (saved, board.changeCount)
        }
        guard let (saved, writeCount) = transaction else {
            insertionFailed = true
            return
        }

        if Self.targetIsFocused(target),
           let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
           let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        } else {
            insertionFailed = true
        }

        Thread.sleep(forTimeInterval: 0.5)
        DispatchQueue.main.sync {
            let board = NSPasteboard.general
            guard board.changeCount == writeCount else { return }
            board.clearContents()
            if !saved.isEmpty && !board.writeObjects(saved) {
                insertionFailed = true
            }
        }
    }

    /// Split a UTF-16 buffer into chunks of at most `maxChunk` code units for
    /// `keyboardSetUnicodeString`, **never splitting a surrogate pair across a chunk
    /// boundary**. A split pair would post a lone high surrogate followed by a lone low
    /// surrogate, which macOS renders as replacement characters instead of the intended
    /// emoji/astral glyph. Pure and static so the boundary math is unit-testable
    /// without CGEvent.
    static func chunks(of utf16: [UInt16], maxChunk: Int = 16) -> [[UInt16]] {
        guard maxChunk > 0 else { return utf16.isEmpty ? [] : [utf16] }
        var result: [[UInt16]] = []
        var offset = 0
        while offset < utf16.count {
            var end = min(offset + maxChunk, utf16.count)
            // If the last unit of this chunk is a high surrogate and a unit follows it
            // (its low surrogate), the pair straddles the boundary — back off by one so
            // the whole pair lands in the next chunk. The `end - 1 > offset` guard keeps
            // the chunk non-empty so progress is guaranteed even for pathological input.
            if end < utf16.count, Self.isHighSurrogate(utf16[end - 1]), end - 1 > offset {
                end -= 1
            }
            result.append(Array(utf16[offset..<end]))
            offset = end
        }
        return result
    }

    private static func isHighSurrogate(_ unit: UInt16) -> Bool {
        (0xD800...0xDBFF).contains(unit)
    }

    /// Barrier that blocks the caller until all previously-enqueued typing has
    /// finished. Because `typingQueue` is serial, a `sync {}` submitted after all the
    /// `async` type() work runs only once that work drains. MUST NOT be called on the
    /// main actor (it blocks). Intended to be called once, from the detached
    /// transcription task, before the done sound / return to idle.
    func flush() -> Bool {
        typingQueue.sync { !insertionFailed }
    }
}
