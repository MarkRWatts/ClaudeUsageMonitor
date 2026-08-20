import ClaudeUsageKit
import SwiftUI

struct HistoryView: View {
    let organizationId: String

    @StateObject private var model = UsageHistoryViewModel()
    @State private var showingClearConfirmation = false

    private let recentWindowCount = 14

    var body: some View {
        List {
            if model.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if model.summary.isEmpty {
                Section {
                    Text("No history recorded yet. Usage is recorded as the app and widget refresh — check back after a few hours.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                windowSection(.fiveHour)
                windowSection(.sevenDay)
                timelineSection
                clearSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(organizationId: organizationId) }
        .refreshable { await model.load(organizationId: organizationId) }
        .confirmationDialog(
            "Delete all recorded usage history?", isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete History", role: .destructive) {
                Task { await model.clear(organizationId: organizationId) }
            }
        } message: {
            Text("This can't be undone, and history only rebuilds from now on.")
        }
    }

    @ViewBuilder
    private func windowSection(_ kind: UsageWindowKind) -> some View {
        let groups = model.summary.groupedWindows(kind, limit: recentWindowCount)
        if !groups.isEmpty {
            Section {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        // Only worth naming the plan when there's more than one to tell apart.
                        if groups.count > 1 {
                            Text(group.planName ?? "Unknown plan")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        SessionPeaksChart(windows: group.windows)
                            .frame(height: 120)
                        if let caption = group.caption {
                            Text(caption)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("\(kind.label) Peaks")
            } footer: {
                if let caveats = model.summary.caveats(for: groups) {
                    Text(caveats)
                }
            }
        }
    }

    private var timelineSection: some View {
        let points = model.summary.timeline(.fiveHour)
        return Section {
            if points.isEmpty {
                Text("No samples in the last 48 hours.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                UsageTimelineChart(
                    points: points, boundaries: model.summary.boundaries, height: 150)
                    .padding(.vertical, 8)
            }
        } header: {
            Text("Last 48 Hours")
        } footer: {
            Text("Each rise is one 5-hour session climbing towards its limit.")
        }
    }

    private var clearSection: some View {
        Section {
            Button("Clear History", role: .destructive) {
                showingClearConfirmation = true
            }
        }
    }
}
