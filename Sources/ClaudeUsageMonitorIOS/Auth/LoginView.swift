import ClaudeUsageKit
import SwiftUI

struct LoginView: View {
    let onCancel: () -> Void

    @StateObject private var viewModel: LoginViewModel

    init(onCancel: @escaping () -> Void, onSuccess: @escaping (StoredCredential) -> Void) {
        self.onCancel = onCancel
        _viewModel = StateObject(wrappedValue: LoginViewModel(onSuccess: onSuccess))
    }

    var body: some View {
        NavigationStack {
            LoginWebView { webView in
                viewModel.attach(webView: webView)
                viewModel.checkForSession()
            }
            .navigationTitle("Log In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear { viewModel.startPolling() }
            .onDisappear { viewModel.stopPolling() }
        }
    }
}
