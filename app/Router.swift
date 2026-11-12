// The Router itself: hold back Marko's hardware input while a session works, then give everything back.
//
// Hardware vs. synthetic: a real key or click from the keyboard and trackpad carries
// kCGEventSourceUnixProcessID == 0. An event posted by a program (Macro Recorder) carries that program's pid.
// So the tap swallows only the events with pid 0 and lets the session's own events straight through.
import AppKit
import CoreGraphics

final class Router {
    private(set) var isBorrowing = false
    private(set) var token: String = ""
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var savedMouse: CGPoint?
    private var savedApp: NSRunningApplication?
    private var deadline: Timer?
    private var escDownSince: CFAbsoluteTime?
    private var typed: [(String, Bool)] = []   // what Marko typed while we held his keyboard: (text, isReturn)
    private let badge = Badge()
    var onChange: (() -> Void)?

    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enabled"); if !newValue { giveBack(reason: "switched off") }; onChange?() }
    }

    // ---------------------------------------------------------------- borrow
    @discardableResult
    func borrow(reason: String, seconds: Double) -> [String: Any] {
        guard enabled else { return ["ok": false, "error": "the Router is switched off in its menu"] }
        if isBorrowing { return ["ok": false, "error": "already borrowed", "token": token] }

        savedMouse = CGEvent(source: nil)?.location
        savedApp = NSWorkspace.shared.frontmostApplication
        token = UUID().uuidString

        // Built with a loop: one long OR chain here made the Swift type-checker time out (12.11.2026).
        let watched: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .scrollWheel,
        ]
        var mask: CGEventMask = 0
        for t in watched { mask |= (CGEventMask(1) << CGEventMask(t.rawValue)) }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<Router>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }

        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                        place: .headInsertEventTap,
                                        options: .defaultTap,
                                        eventsOfInterest: mask,
                                        callback: callback,
                                        userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return ["ok": false,
                    "error": "macOS has not granted Accessibility and Input Monitoring to this app yet. "
                           + "System Settings > Privacy & Security > Accessibility, and Input Monitoring."]
        }
        tap = t
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)

        isBorrowing = true
        let secs = min(max(seconds, 1), 120)
        badge.show(reason: reason.isEmpty ? "working" : reason, on: NSScreen.main)
        deadline = Timer.scheduledTimer(withTimeInterval: secs, repeats: false) { [weak self] _ in
            self?.giveBack(reason: "the time ran out")
        }
        onChange?()
        return ["ok": true, "token": token, "seconds": secs]
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let pid = event.getIntegerValueField(.eventSourceUnixProcessID)
        if pid != 0 { return Unmanaged.passUnretained(event) }     // a program's own event: let it through

        // Marko's own hardware. Escape held for two seconds takes everything back.
        if type == .keyDown, event.getIntegerValueField(.keyboardEventKeycode) == 53 {
            let now = CFAbsoluteTimeGetCurrent()
            if let since = escDownSince {
                if now - since >= 2.0 {
                    DispatchQueue.main.async { [weak self] in self?.giveBack(reason: "you took them back") }
                }
            } else {
                escDownSince = now
                DispatchQueue.main.async { [weak self] in self?.badge.update(reason: "keep holding Escape…") }
            }
        }
        if type == .keyUp, event.getIntegerValueField(.keyboardEventKeycode) == 53 { escDownSince = nil }

        // Marko, 12.11.2026: "it keeps buffering my own typing, so when you finish using keyboard and mouse it just
        // continues typing in the same box where I was." Keep every character he typed while we had his keyboard,
        // and give it back to him, in order, into whatever he was typing in.
        if type == .keyDown {
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if code == 36 || code == 76 {                           // Return / Enter: keep it as a key, not a character
                typed.append(("", true))
            } else if code != 53 {                                  // Escape is the escape hatch, never replayed
                var length = 0
                var chars = [UniChar](repeating: 0, count: 8)
                event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &chars)
                if length > 0 {
                    let s = String(utf16CodeUnits: chars, count: length)
                    if !s.isEmpty, s.unicodeScalars.allSatisfy({ $0.value >= 32 || $0.value == 9 }) {
                        typed.append((s, false))
                    }
                }
            }
        }
        return nil                                                  // swallowed
    }

    // ---------------------------------------------------------------- give back
    func giveBack(reason: String) {
        guard isBorrowing else { return }
        deadline?.invalidate(); deadline = nil
        if let s = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false) }
        tap = nil; runLoopSource = nil; escDownSince = nil
        if let p = savedMouse { CGWarpMouseCursorPosition(p); CGAssociateMouseAndMouseCursorPosition(1) }
        savedApp?.activate()
        badge.hide()
        replayTyping()
        isBorrowing = false
        token = ""
        savedMouse = nil; savedApp = nil
        onChange?()
        NSLog("[router] gave them back: \(reason)")
    }

    /// Everything Marko typed while we held his keyboard, put back into whatever he was typing in.
    /// The front app is restored first, so the characters land where he left off.
    private func replayTyping() {
        let buffered = typed
        typed = []
        guard !buffered.isEmpty else { return }
        // a short wait so the app he was in is really focused again before the characters arrive
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let src = CGEventSource(stateID: .privateState)
            for (text, isReturn) in buffered {
                if isReturn {
                    // Return is given back as a real key, so a text box that submits on Enter behaves as he expects
                    if let d = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: true),
                       let u = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: false) {
                        d.post(tap: .cghidEventTap); u.post(tap: .cghidEventTap)
                    }
                } else {
                    var units = Array(text.utf16)
                    if let d = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true),
                       let u = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) {
                        d.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
                        u.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
                        d.post(tap: .cghidEventTap); u.post(tap: .cghidEventTap)
                    }
                }
                usleep(6000)
            }
            NSLog("[router] gave back \(buffered.count) keystroke(s) Marko typed while we had the keyboard")
        }
    }

    func status() -> [String: Any] {
        ["ok": true, "enabled": enabled, "borrowing": isBorrowing, "version": VERSION,
         "buffered_keystrokes": typed.count,
         "front_app": savedApp?.localizedName ?? NSWorkspace.shared.frontmostApplication?.localizedName ?? ""]
    }
}
