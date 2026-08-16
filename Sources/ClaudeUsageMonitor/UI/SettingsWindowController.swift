import AppKit
import ClaudeUsageKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?

    func show(
        store: UsageStore, credential: StoredCredential?, onSignOut: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        let window: NSWindow
        if let existing = self.window {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false)
            window.title = "Settings"
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        window.contentView = NSHostingView(
            rootView: SettingsView(
                store: store,
                organizationName: credential?.organizationName ?? "Not signed in",
                organizationId: credential?.organizationId ?? "—",
                loggedInAt: credential?.loggedInAt,
                onSignOut: { [weak self] in
                    onSignOut()
                    self?.window?.close()
                },
                onQuit: onQuit,
                onClose: { [weak self] in
                    self?.window?.close()
                }))

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
