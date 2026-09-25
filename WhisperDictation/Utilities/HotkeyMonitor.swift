import Cocoa
import CoreGraphics
import os

final class HotkeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retainedSelfPtr: UnsafeMutableRawPointer?
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void
    private let onTapStateChange: (Bool) -> Void
    private let lock = os_unfair_lock_t.allocate(capacity: 1)

    private var monitoredKeyCode: CGKeyCode {
        CGKeyCode(AppSettings.shared.hotkeyKeyCode)
    }

    private var isModifierKey: Bool {
        KeyCodeNames.isModifier(Int(monitoredKeyCode))
    }

    private var isKeyHeld = false
    private var lastReportedTapState = false

    /// Whether macOS currently reports the global event tap as enabled.
    var isActive: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void,
         onTapStateChange: @escaping (Bool) -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        self.onTapStateChange = onTapStateChange
        lock.initialize(to: os_unfair_lock())
    }

    private func reportTapStateIfChanged() {
        let active = isActive
        guard active != lastReportedTapState else { return }
        lastReportedTapState = active
        onTapStateChange(active)
    }

    deinit {
        stop()
        lock.deallocate()
    }

    func start() {
        guard eventTap == nil else { return }
        fputs("[HotkeyMonitor] Starting... keyCode=\(monitoredKeyCode) isModifier=\(isModifierKey)\n", stderr)

        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handleEvent(type: type, event: event)
            },
            userInfo: selfPtr
        )

        guard let eventTap else {
            fputs("[HotkeyMonitor] FAILED to create event tap! Grant Accessibility permission in System Settings.\n", stderr)
            Unmanaged<HotkeyMonitor>.fromOpaque(selfPtr).release()
            reportTapStateIfChanged()
            return
        }

        fputs("[HotkeyMonitor] Event tap created successfully\n", stderr)
        retainedSelfPtr = selfPtr

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        reportTapStateIfChanged()

        // Watchdog: macOS silently disables taps when Accessibility permission is stale.
        // Schedule explicitly on main run loop to guarantee it fires.
        startTapWatchdog()
    }

    private var watchdogTimer: Timer?

    private func startTapWatchdog() {
        watchdogTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, let tap = self.eventTap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                self.reportTapStateIfChanged()
                fputs("[HotkeyMonitor] Event tap was disabled by macOS! Re-enabling...\n", stderr)
                CGEvent.tapEnable(tap: tap, enable: true)
                self.reportTapStateIfChanged()
                // The tap was disabled — any in-flight key-down lost its key-up event.
                // Reset isKeyHeld so the next press is accepted, AND synthesize the missed
                // key-up so DictationEngine can recover (otherwise it stays stuck in
                // .recording for push-to-talk, or in `isHoldingForToggle = true` with a
                // pending work item for toggle mode).
                os_unfair_lock_lock(self.lock)
                let wasHeld = self.isKeyHeld
                self.isKeyHeld = false
                os_unfair_lock_unlock(self.lock)
                if wasHeld {
                    DispatchQueue.main.async { self.onKeyUp() }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdogTimer = timer
    }

    func stop() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        os_unfair_lock_lock(lock)
        let wasHeld = isKeyHeld
        isKeyHeld = false
        os_unfair_lock_unlock(lock)
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }
        if let ptr = retainedSelfPtr {
            Unmanaged<HotkeyMonitor>.fromOpaque(ptr).release()
            retainedSelfPtr = nil
        }
        reportTapStateIfChanged()
        if wasHeld {
            let callback = onKeyUp
            DispatchQueue.main.async(execute: callback)
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if isModifierKey {
            if type == .flagsChanged && keyCode == monitoredKeyCode {
                os_unfair_lock_lock(lock)
                let wasHeld = isKeyHeld
                // flagsChanged identifies the physical modifier by key code. The
                // aggregate Option/Command/etc. flag can remain set when the other
                // side is held, so use this key's own transition instead.
                if !wasHeld {
                    isKeyHeld = true
                    os_unfair_lock_unlock(lock)
                    DispatchQueue.main.async { self.onKeyDown() }
                    return nil
                } else {
                    isKeyHeld = false
                    os_unfair_lock_unlock(lock)
                    DispatchQueue.main.async { self.onKeyUp() }
                    return nil
                }
            }
        } else {
            if keyCode == monitoredKeyCode {
                os_unfair_lock_lock(lock)
                let wasHeld = isKeyHeld
                if type == .keyDown && !wasHeld {
                    isKeyHeld = true
                    os_unfair_lock_unlock(lock)
                    DispatchQueue.main.async { self.onKeyDown() }
                    return nil
                } else if type == .keyUp && wasHeld {
                    isKeyHeld = false
                    os_unfair_lock_unlock(lock)
                    DispatchQueue.main.async { self.onKeyUp() }
                    return nil
                }
                os_unfair_lock_unlock(lock)
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
