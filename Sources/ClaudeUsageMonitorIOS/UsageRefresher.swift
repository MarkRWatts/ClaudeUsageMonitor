import ClaudeUsageKit
import WidgetKit

/// Fetches usage + org plan, updates the cache the widget reads from, and reloads widget
/// timelines — shared between the foreground poll (`RootView`) and the `BGAppRefreshTask`
/// handler (`BackgroundRefreshScheduler`), which has no `UsageStore` of its own to update.
enum UsageRefresher {
    enum Outcome: Equatable {
        case success
        case unauthorized
        case failure
    }

    @discardableResult
    static func refresh(store: UsageStore?) async -> Outcome {
        guard let credential = CredentialStore.load() else { return .unauthorized }

        do {
            let usage = try await UsageAPIClient.fetchUsage(credential)
            let organization = try? await UsageAPIClient.fetchOrganization(
                cookieHeader: credential.cookieHeader)
            let planName = organization?.planName

            UsageSnapshotCache.save(usage, planName: planName)
            if let store {
                await MainActor.run {
                    store.apply(usage)
                    store.planName = planName
                }
            }
            WidgetCenter.shared.reloadAllTimelines()
            return .success
        } catch UsageAPIError.unauthorized {
            CredentialStore.clear()
            if let store {
                await MainActor.run { store.reset() }
            }
            WidgetCenter.shared.reloadAllTimelines()
            return .unauthorized
        } catch {
            DebugLog.write("UsageRefresher.refresh failed: \(error)")
            return .failure
        }
    }
}
