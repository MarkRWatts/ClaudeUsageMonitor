import ClaudeUsageKit
import WidgetKit

struct Provider: TimelineProvider {
    private let refreshInterval: TimeInterval = 45 * 60
    private let retryInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> UsageEntry {
        if let cached = UsageSnapshotCache.load() {
            return .from(response: cached.response, planName: cached.planName, date: Date(), isStale: false)
        }
        return .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            if let cached = UsageSnapshotCache.load() {
                completion(.from(response: cached.response, planName: cached.planName, date: Date(), isStale: false))
            } else {
                completion(.placeholder)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        Task {
            guard let credential = CredentialStore.load() else {
                completion(Timeline(entries: [.signedOut], policy: .after(Date().addingTimeInterval(refreshInterval))))
                return
            }

            do {
                async let usageTask = UsageAPIClient.fetchUsage(credential)
                async let organizationTask = try? UsageAPIClient.fetchOrganization(
                    cookieHeader: credential.cookieHeader)
                let usage = try await usageTask
                let planName = await organizationTask?.planName
                UsageSnapshotCache.save(usage, planName: planName)

                var entries = [UsageEntry.from(response: usage, planName: planName, date: Date(), isStale: false)]
                var nextReload = Date().addingTimeInterval(refreshInterval)

                if let resetsAt = usage.fiveHour?.resetsAt, resetsAt > Date() {
                    entries.append(
                        UsageEntry(
                            date: resetsAt,
                            fiveHourPercent: 0,
                            fiveHourResetsAt: nil,
                            sevenDayPercent: usage.sevenDay?.utilization ?? 0,
                            sevenDayResetsAt: usage.sevenDay?.resetsAt,
                            spendPercent: usage.spend?.percent ?? 0,
                            spendUsedFormatted: usage.spend?.used?.formatted ?? "—",
                            spendLimitFormatted: usage.spend?.limit?.formatted ?? "—",
                            planName: planName,
                            isSignedIn: true,
                            isStale: false))
                    nextReload = min(resetsAt, nextReload)
                }

                completion(Timeline(entries: entries, policy: .after(nextReload)))
            } catch {
                DebugLog.write("Widget Provider.getTimeline failed: \(error)")
                if let cached = UsageSnapshotCache.load() {
                    let entry = UsageEntry.from(
                        response: cached.response, planName: cached.planName, date: Date(), isStale: true)
                    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(retryInterval))))
                } else {
                    completion(Timeline(entries: [.signedOut], policy: .after(Date().addingTimeInterval(retryInterval))))
                }
            }
        }
    }
}
