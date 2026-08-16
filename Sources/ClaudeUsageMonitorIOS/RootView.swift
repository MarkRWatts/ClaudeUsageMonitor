import ClaudeUsageKit
import SwiftUI

struct RootView: View {
    @ObservedObject var store: UsageStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var credential: StoredCredential?
    @State private var isCheckingSession = true
    @State private var showingLogin = false
    @State private var foregroundTimer: Timer?

    private let foregroundInterval: TimeInterval = 60

    var body: some View {
        Group {
            if let credential {
                NavigationStack {
                    UsageDashboardView(
                        store: store,
                        organizationName: credential.organizationName,
                        organizationId: credential.organizationId,
                        loggedInAt: credential.loggedInAt,
                        onRefresh: { await refreshAndSync() },
                        onSignOut: signOut)
                }
            } else if !isCheckingSession {
                SignedOutView(onSignIn: { showingLogin = true })
            } else {
                ProgressView()
            }
        }
        .fullScreenCover(isPresented: $showingLogin) {
            LoginView(
                onCancel: { showingLogin = false },
                onSuccess: { newCredential in
                    credential = newCredential
                    showingLogin = false
                    startForegroundPolling()
                    Task { await refreshAndSync() }
                })
        }
        .task {
            credential = CredentialStore.load()
            isCheckingSession = false
            if credential != nil {
                startForegroundPolling()
                await refreshAndSync()
            } else {
                showingLogin = true
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                credential = CredentialStore.load()
                if credential != nil {
                    startForegroundPolling()
                    Task { await refreshAndSync() }
                } else {
                    stopForegroundPolling()
                }
            case .background, .inactive:
                stopForegroundPolling()
                BackgroundRefreshScheduler.schedule()
            @unknown default:
                break
            }
        }
    }

    private func startForegroundPolling() {
        stopForegroundPolling()
        foregroundTimer = Timer.scheduledTimer(withTimeInterval: foregroundInterval, repeats: true) { _ in
            Task { await refreshAndSync() }
        }
    }

    private func stopForegroundPolling() {
        foregroundTimer?.invalidate()
        foregroundTimer = nil
    }

    private func refreshAndSync() async {
        let outcome = await UsageRefresher.refresh(store: store)
        if outcome == .unauthorized {
            await MainActor.run {
                credential = nil
                stopForegroundPolling()
                showingLogin = true
            }
        }
    }

    private func signOut() {
        stopForegroundPolling()
        CredentialStore.clear()
        store.reset()
        credential = nil
    }
}

private struct SignedOutView: View {
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Not Signed In")
                .font(.title3.bold())
            Button("Sign In", action: onSignIn)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
