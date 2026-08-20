import ClaudeUsageKit
import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var store: UsageStore
    let onOpenSettings: () -> Void

    @StateObject private var history = UsageHistoryViewModel()

    private let sparklineWindowCount = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Claude Usage")
                    .font(.system(size: 13, weight: .bold))
                if let planName = store.planName {
                    Text(planName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                UsageBarRow(
                    title: "5-Hour Session",
                    percent: store.fiveHourPercent,
                    subtitle: UsageFormatting.resetsSubtitle(store.fiveHourResetsAt))

                if !recentSessions.isEmpty {
                    UsageSparkline(windows: recentSessions)
                    Text("Last \(recentSessions.count) sessions")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            UsageBarRow(
                title: "Weekly (All Models)",
                percent: store.sevenDayPercent,
                subtitle: UsageFormatting.resetsSubtitle(store.sevenDayResetsAt))

            UsageBarRow(
                title: "Usage Credits",
                percent: store.spendPercent,
                subtitle: "\(store.spendUsedFormatted) of \(store.spendLimitFormatted)")

            if let lastUpdated = store.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 260)
        .task { await loadHistory() }
        // `lastUpdated` moving means a refresh just landed and was recorded, which is exactly
        // when the sparkline has something new to show.
        .onChange(of: store.lastUpdated) { _ in
            Task { await loadHistory() }
        }
    }

    /// The most recent windows from the current plan only — a sparkline is too small to carry
    /// the caveat that bars either side of a plan change measure against different limits.
    private var recentSessions: [HistoryWindow] {
        history.summary.groupedWindows(.fiveHour, limit: sparklineWindowCount).last?.windows ?? []
    }

    private func loadHistory() async {
        guard let organizationId = CredentialStore.load()?.organizationId else { return }
        await history.load(organizationId: organizationId, sampleWindow: nil)
    }
}
