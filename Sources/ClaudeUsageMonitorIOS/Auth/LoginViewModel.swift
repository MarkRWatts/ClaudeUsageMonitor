import ClaudeUsageKit
import Combine
import WebKit

/// Same technique as the mac app's `LoginWindowController`: poll the WebView's cookie store
/// every 1.5s (and after every navigation) until claude.ai session cookies appear, then
/// validate them against the API and save the resulting credential.
@MainActor
final class LoginViewModel: ObservableObject {
    private let onSuccess: (StoredCredential) -> Void
    private var pollTimer: Timer?
    private var isChecking = false
    private weak var webView: WKWebView?

    init(onSuccess: @escaping (StoredCredential) -> Void) {
        self.onSuccess = onSuccess
    }

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForSession() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func checkForSession() {
        guard !isChecking, let webView else { return }
        isChecking = true

        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let credential = try await AuthSessionBuilder.credential(fromCookies: cookies)
                    CredentialStore.save(credential)
                    self.stopPolling()
                    self.onSuccess(credential)
                } catch {
                    // Not authenticated yet — the next poll tick or navigation retries.
                    self.isChecking = false
                }
            }
        }
    }
}
