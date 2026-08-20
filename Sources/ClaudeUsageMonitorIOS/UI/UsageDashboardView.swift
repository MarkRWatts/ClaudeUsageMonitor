import ClaudeUsageKit
import SwiftUI

struct UsageDashboardView: View {
    @ObservedObject var store: UsageStore
    let organizationName: String
    let organizationId: String
    let loggedInAt: Date?
    let onRefresh: () async -> Void
    let onSignOut: () -> Void

    var body: some View {
        List {
            if let planName = store.planName {
                Section {
                    HStack {
                        Text("Plan")
                        Spacer()
                        Text(planName).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                UsageBarRow(
                    title: "5-Hour Session",
                    percent: store.fiveHourPercent,
                    subtitle: UsageFormatting.resetsSubtitle(store.fiveHourResetsAt))
                UsageBarRow(
                    title: "Weekly (All Models)",
                    percent: store.sevenDayPercent,
                    subtitle: UsageFormatting.resetsSubtitle(store.sevenDayResetsAt))
                UsageBarRow(
                    title: "Usage Credits",
                    percent: store.spendPercent,
                    subtitle: "\(store.spendUsedFormatted) of \(store.spendLimitFormatted)")
            } header: {
                Text("Current Limits")
            } footer: {
                if let lastUpdated = store.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative) ago")
                }
            }

            Section {
                NavigationLink {
                    HistoryView(organizationId: organizationId)
                } label: {
                    Label("History", systemImage: "chart.bar.xaxis")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Claude Usage")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView(
                        organizationName: organizationName,
                        organizationId: organizationId,
                        loggedInAt: loggedInAt,
                        onSignOut: onSignOut)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .refreshable {
            await onRefresh()
        }
    }
}
