import AppKit
import Combine
import SwiftUI

final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?
    private let onOpen: () -> Void
    private let onClose: () -> Void
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    init(
        store: UsageStore, onOpen: @escaping () -> Void, onClose: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.onOpen = onOpen
        self.onClose = onClose
        super.init()

        if let button = statusItem.button {
            button.image = UsageRingRenderer.image(percent: 0)
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: UsagePopoverView(store: store, onOpenSettings: onOpenSettings))

        cancellable = store.$fiveHourPercent.sink { [weak self] percent in
            self?.statusItem.button?.image = UsageRingRenderer.image(percent: percent)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            onOpen()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startClickMonitors()
        }
    }

    private func startClickMonitors() {
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            // Ignore clicks on the status item's own button — togglePopover's
            // target-action already handles closing it, and closing here first
            // would make the button's action immediately reopen it.
            if let self, event.window !== self.statusItem.button?.window {
                self.popover.performClose(nil)
            }
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    private func stopClickMonitors() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopClickMonitors()
        onClose()
    }
}
