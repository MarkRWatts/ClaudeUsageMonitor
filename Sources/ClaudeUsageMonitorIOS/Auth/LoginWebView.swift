import SwiftUI
import WebKit

/// Hosts the claude.ai login page. `onNavigationFinished` fires after every page load — the
/// same signal the mac app's `WKNavigationDelegate.didFinish` uses to re-check for a session
/// cookie, since we can't know in advance which navigation completes the login form.
struct LoginWebView: UIViewRepresentable {
    let onNavigationFinished: (WKWebView) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onNavigationFinished: onNavigationFinished)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onNavigationFinished: (WKWebView) -> Void

        init(onNavigationFinished: @escaping (WKWebView) -> Void) {
            self.onNavigationFinished = onNavigationFinished
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onNavigationFinished(webView)
        }
    }
}
