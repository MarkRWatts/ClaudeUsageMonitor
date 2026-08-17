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

            // WidgetKit only grants a small shared reload budget per day; reloading on every
            // foreground poll (every 60s) even when nothing changed burns through it fast and
            // leaves the widget frozen once it's exhausted. Only reload when the numbers the
            // widget actually shows have moved.
            let previousSignature = UsageSnapshotCache.load().map { summary($0.response, planName: $0.planName) }
            UsageSnapshotCache.save(usage, planName: planName)
            if let store {
                await MainActor.run {
                    store.apply(usage)
                    store.planName = planName
                }
            }
            if previousSignature == nil || previousSignature != summary(usage, planName: planName) {
                WidgetCenter.shared.reloadAllTimelines()
            }
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

    /// Signature of everything the widget actually renders, so `refresh` can tell whether a
    /// reload is worth its share of WidgetKit's daily budget.
    private static func summary(_ response: UsageResponse, planName: String?) -> String {
        let fiveHourResets = response.fiveHour?.resetsAt?.timeIntervalSince1970
        let sevenDayResets = response.sevenDay?.resetsAt?.timeIntervalSince1970
        return
            "\(response.fiveHour?.utilization ?? -1)|\(fiveHourResets ?? -1)|"
            + "\(response.sevenDay?.utilization ?? -1)|\(sevenDayResets ?? -1)|"
            + "\(response.spend?.percent ?? -1)|\(planName ?? "")"
    }
}
