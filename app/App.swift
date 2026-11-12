// Keyboard and Mouse Router (Mantra)
// Marko, 12.11.2026: "Please build now this keyboard and mouse router between me and you. When you're moving the
// mouse or using the keyboard, you need to put a small badge in the middle of the screen, and it should say
// 'Claude is borrowing your mouse and keyboard.'"
//
// Why it exists: on 12.11.2026 a session typed a ten-line list while WinActivate had silently failed. Every line
// went into Marko's own prompt and was sent. The Router makes that impossible: while a session borrows the
// keyboard and mouse, Marko's hardware input is held back, a badge says so, and when the session gives them back
// the pointer and the front window are exactly where they were.
import AppKit

let VERSION = 1

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    let router = Router()
    var server: Server!

    func applicationDidFinishLaunching(_ note: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        redrawMenu()
        router.onChange = { [weak self] in DispatchQueue.main.async { self?.redrawMenu() } }
        server = Server(router: router, port: 8870)
        server.start()
    }

    @objc func toggleEnabled() { router.enabled.toggle() }
    @objc func giveBack() { router.giveBack(reason: "returned from the menu") }
    @objc func quit() { router.giveBack(reason: "quitting"); NSApp.terminate(nil) }

    func redrawMenu() {
        let borrowing = router.isBorrowing
        item.button?.title = borrowing ? "⌨︎●" : "⌨︎"
        item.button?.toolTip = borrowing
            ? "Claude is borrowing your mouse and keyboard"
            : "Keyboard and Mouse Router — idle"
        let menu = NSMenu()
        menu.addItem(withTitle: borrowing ? "Claude is borrowing them now" : "Idle — they are yours",
                     action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let e = NSMenuItem(title: "Let Claude borrow them", action: #selector(toggleEnabled), keyEquivalent: "")
        e.target = self
        e.state = router.enabled ? .on : .off
        menu.addItem(e)
        if borrowing {
            let g = NSMenuItem(title: "Give them back now", action: #selector(giveBack), keyEquivalent: "")
            g.target = self
            menu.addItem(g)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hold Escape for two seconds to take them back", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Listening on 127.0.0.1:8870  ·  v\(VERSION)", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let q = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        q.target = self
        menu.addItem(q)
        item.menu = menu
    }
}
