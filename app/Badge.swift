// The badge: a small panel in the middle of the screen while Claude has the mouse and keyboard.
import AppKit

final class Badge {
    private var window: NSPanel?
    private var label: NSTextField?
    private var sub: NSTextField?

    func show(reason: String, on screen: NSScreen?) {
        hide()
        let w: CGFloat = 520, h: CGFloat = 104
        let scr = screen ?? NSScreen.main ?? NSScreen.screens.first!
        let f = scr.frame
        let rect = NSRect(x: f.midX - w / 2, y: f.midY - h / 2, width: w, height: h)
        let panel = NSPanel(contentRect: rect,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let box = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        box.material = .hudWindow
        box.state = .active
        box.wantsLayer = true
        box.layer?.cornerRadius = 18
        box.layer?.masksToBounds = true
        box.layer?.borderWidth = 1
        box.layer?.borderColor = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.19, alpha: 0.85).cgColor

        let title = NSTextField(labelWithString: "Claude is borrowing your mouse and keyboard")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.textColor = .white
        title.alignment = .center
        title.frame = NSRect(x: 16, y: 52, width: w - 32, height: 26)
        box.addSubview(title)

        let detail = NSTextField(labelWithString: reason)
        detail.font = .systemFont(ofSize: 12, weight: .regular)
        detail.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.72)
        detail.alignment = .center
        detail.lineBreakMode = .byTruncatingTail
        detail.frame = NSRect(x: 16, y: 30, width: w - 32, height: 18)
        box.addSubview(detail)

        let hint = NSTextField(labelWithString: "hold Escape for two seconds to take them back")
        hint.font = .systemFont(ofSize: 11, weight: .regular)
        hint.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.45)
        hint.alignment = .center
        hint.frame = NSRect(x: 16, y: 10, width: w - 32, height: 16)
        box.addSubview(hint)

        panel.contentView = box
        panel.orderFrontRegardless()
        window = panel
        label = title
        sub = detail
    }

    func update(reason: String) { sub?.stringValue = reason }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}
