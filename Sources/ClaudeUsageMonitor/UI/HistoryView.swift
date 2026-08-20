import ClaudeUsageKit
import SwiftUI

struct HistoryView: View {
    let organizationId: String
    let onClose: () -> Void

    @StateObject private var model = UsageHistoryViewModel()
    @State private var showingClearConfirmation = false

    private let recentWindowCount = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage History")
                .font(.system(size: 15, weight: .bold))

            if model.isLoading {
                centered { ProgressView() }
            } else if model.summary.isEmpty {
                centered {
                    Text("No history recorded yet. Usage is recorded every few minutes while the app is running — check back after a few hours.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                windowGroup(.fiveHour)
                windowGroup(.sevenDay)
                timelineGroup
            }

            Divider()

            HStack {
                Button("Clear History", role: .destructive) {
                    showingClearConfirmation = true
                }
                .disabled(model.summary.isEmpty)
                Spacer()
                Button("Close", action: onClose)
            }
        }
        .padding(20)
        .frame(width: 420)
        .task { await model.load(organizationId: organizationId) }
        .confirmationDialog(
            "Delete all recorded usage history?", isPresented: $showingClearConfirmation
        ) {
            Button("Delete History", role: .destructive) {
                Task { await model.clear(organizationId: organizationId) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone, and history only rebuilds from now on.")
        }
    }

    @ViewBuilder
    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(height: 120)
    }

    @ViewBuilder
    private func windowGroup(_ kind: UsageWindowKind) -> some View {
        let groups = model.summary.groupedWindows(kind, limit: recentWindowCount)
        if !groups.isEmpty {
            GroupBox("\(kind.label) Peaks") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(groups) { group in
                        // Only worth naming the plan when there's more than one to tell apart.
                        if groups.count > 1 {
                            Text(group.planName ?? "Unknown plan")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        SessionPeaksChart(windows: group.windows)
                            .frame(height: 90)
                        if let caption = group.caption {
                            Text(caption)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    footer(for: groups)
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var timelineGroup: some View {
        let points = model.summary.timeline(.fiveHour)
        GroupBox("Last 48 Hours") {
            VStack(alignment: .leading, spacing: 6) {
                if points.isEmpty {
                    Text("No samples in the last 48 hours.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    UsageTimelineChart(points: points, boundaries: model.summary.boundaries)
                    Text("Each rise is one 5-hour session climbing towards its limit.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func footer(for groups: [HistoryEpochGroup]) -> some View {
        if let text = model.summary.caveats(for: groups) {
            Text(text)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
