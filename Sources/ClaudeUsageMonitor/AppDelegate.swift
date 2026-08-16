import AppKit
import ClaudeUsageKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private let loginController = LoginWindowController()
    private let settingsWindowController = SettingsWindowController()
    private var statusItemController: StatusItemController?

    private var foregroundTimer: Timer?
    private var backgroundTimer: Timer?

    private let foregroundInterval: TimeInterval = 60
    private let backgroundInterval: TimeInterval = 180

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(
            store: store,
            onOpen: { [weak self] in
                self?.startForegroundPolling()
                Task { await self?.refresh() }
            },
            onClose: { [weak self] in
                self?.stopForegroundPolling()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            })

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification,
            object: nil)

        startBackgroundTimer()
        Task { await ensureAuthenticatedAndRefresh() }
    }

    @objc private func handleWake() {
        Task { await refresh() }
    }

    private func startBackgroundTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = Timer.scheduledTimer(
            withTimeInterval: backgroundInterval, repeats: true
        ) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    private func startForegroundPolling() {
        stopForegroundPolling()
        foregroundTimer = Timer.scheduledTimer(
            withTimeInterval: foregroundInterval, repeats: true
        ) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    private func stopForegroundPolling() {
        foregroundTimer?.invalidate()
        foregroundTimer = nil
    }

    private func openSettings() {
        settingsWindowController.show(
            store: store,
            credential: CredentialStore.load(),
            onSignOut: { [weak self] in
                self?.signOut()
            },
            onQuit: {
                NSApp.terminate(nil)
            })
    }

    private func signOut() {
        stopForegroundPolling()
        store.reset()
        loginController.logout { [weak self] in
            Task { await self?.ensureAuthenticatedAndRefresh() }
        }
    }

    private func ensureAuthenticatedAndRefresh() async {
        if CredentialStore.load() == nil {
            await MainActor.run {
                loginController.presentLogin { [weak self] _ in
                    Task { await self?.refresh() }
                }
            }
        } else {
            await refresh()
        }
    }

    private func refresh() async {
        guard let credential = CredentialStore.load() else {
            await ensureAuthenticatedAndRefresh()
            return
        }

        do {
            let usage = try await UsageAPIClient.fetchUsage(credential)
            await MainActor.run { store.apply(usage) }
            if let organization = try? await UsageAPIClient.fetchOrganization(
                cookieHeader: credential.cookieHeader)
            {
                await MainActor.run { store.planName = organization.planName }
            }
        } catch UsageAPIError.unauthorized {
            CredentialStore.clear()
            await MainActor.run {
                loginController.presentLogin { [weak self] _ in
                    Task { await self?.refresh() }
                }
            }
        } catch {
            // Transient network error — the next timer tick retries.
        }
    }
}
