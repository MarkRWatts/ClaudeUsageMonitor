import ClaudeUsageKit
import SwiftUI

@main
struct ClaudeUsageMonitorIOSApp: App {
    @StateObject private var store = UsageStore()

    init() {
        CredentialStore.accessGroup = AppGroup.identifier
        BackgroundRefreshScheduler.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
