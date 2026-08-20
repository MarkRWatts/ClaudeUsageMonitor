import ClaudeUsageKit
import Foundation

/// Loads recorded history off the main thread and holds it for the history screens.
@MainActor
final class UsageHistoryViewModel: ObservableObject {
    @Published private(set) var summary: UsageHistorySummary = .empty
    @Published private(set) var isLoading = true

    func load(organizationId: String, sampleWindow: TimeInterval? = 48 * 60 * 60) async {
        isLoading = true
        summary = await Task.detached(priority: .userInitiated) {
            UsageHistorySummary.load(organizationId: organizationId, sampleWindow: sampleWindow)
        }.value
        isLoading = false
    }

    func clear(organizationId: String) async {
        await Task.detached(priority: .userInitiated) {
            UsageHistoryStore.clear(organizationId: organizationId)
        }.value
        await load(organizationId: organizationId)
    }
}
