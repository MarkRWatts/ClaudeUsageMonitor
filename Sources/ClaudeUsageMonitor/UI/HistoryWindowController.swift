import AppKit
import ClaudeUsageKit
import SwiftUI

final class HistoryWindowController {
    private var window: NSWindow?

    func show(organizationId: String) {
        let window: NSWindow
        if let existing = self.window {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false)
            window.title = "Usage History"
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        window.contentView = NSHostingView(
            rootView: HistoryView(
                organizationId: organizationId,
                onClose: { [weak self] in
                    self?.window?.close()
                }))

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
