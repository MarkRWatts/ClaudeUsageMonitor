import AppKit
import WebKit

final class LoginWindowController: NSObject, WKNavigationDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var completion: ((StoredCredential) -> Void)?
    private var pollTimer: Timer?
    private var isChecking = false

    func presentLogin(completion: @escaping (StoredCredential) -> Void) {
        self.completion = completion

        // Reuse the existing (possibly hidden) window/webView rather than ever deallocating
        // and recreating one — see closeWindowSafely() for why.
        let webView: WKWebView
        if let existing = self.webView {
            webView = existing
        } else {
            webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 480, height: 640))
            webView.navigationDelegate = self
            self.webView = webView
        }

        let window: NSWindow
        if let existing = self.window {
            window = existing
        } else {
            window = NSWindow(
                contentRect: webView.frame,
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false)
            window.title = "Log in to Claude"
            window.contentView = webView
            window.isReleasedWhenClosed = false
            self.window = window
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkForSession()
        }
    }

    private func checkForSession() {
        guard !isChecking, let webView else { return }
        isChecking = true

        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            let claudeCookies = cookies.filter { $0.domain.hasSuffix("claude.ai") }
            guard !claudeCookies.isEmpty else {
                self.isChecking = false
                return
            }
            let cookieHeader = claudeCookies.map { "\($0.name)=\($0.value)" }.joined(
                separator: "; ")

            Task {
                do {
                    let organization = try await UsageAPIClient.fetchOrganization(
                        cookieHeader: cookieHeader)
                    let credential = StoredCredential(
                        cookieHeader: cookieHeader,
                        organizationId: organization.uuid,
                        organizationName: organization.name,
                        loggedInAt: Date())
                    CredentialStore.save(credential)
                    await MainActor.run {
                        self.pollTimer?.invalidate()
                        self.pollTimer = nil
                        self.closeWindowSafely()
                        self.completion?(credential)
                    }
                } catch {
                    // Not authenticated yet (still filling in the login form) — the next
                    // poll tick or navigation will retry.
                    await MainActor.run { self.isChecking = false }
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkForSession()
    }

    /// Deallocating an NSWindow/WKWebView right after a navigation completes can crash inside
    /// WebKit's own teardown (EXC_BAD_ACCESS in AutoreleasePoolPage, unrelated to our code —
    /// a known WKWebView issue). Just hiding the window and keeping it alive sidesteps it
    /// entirely; the window is reused (reloaded) the next time login is needed.
    private func closeWindowSafely() {
        window?.orderOut(nil)
    }

    /// Clears our stored credential and the actual claude.ai session data (cookies, local
    /// storage) so the next login genuinely requires re-authenticating, not just a silent
    /// cookie-replay.
    func logout(completion: @escaping () -> Void) {
        CredentialStore.clear()
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            let claudeRecords = records.filter { $0.displayName.contains("claude.ai") }
            dataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: claudeRecords
            ) {
                DispatchQueue.main.async { completion() }
            }
        }
    }
}
