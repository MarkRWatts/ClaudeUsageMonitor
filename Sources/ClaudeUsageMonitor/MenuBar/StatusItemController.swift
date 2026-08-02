import AppKit
import Combine
import SwiftUI

final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?
    private let onOpen: () -> Void
    private let onClose: () -> Void

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
        }
    }

    func popoverDidClose(_ notification: Notification) {
        onClose()
    }
}
