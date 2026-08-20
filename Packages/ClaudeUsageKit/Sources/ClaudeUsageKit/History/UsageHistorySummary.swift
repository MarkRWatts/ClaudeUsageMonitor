import Foundation

/// One limit window, resolved against the plan epoch it belongs to and ready to plot.
public struct HistoryWindow: Identifiable {
    public let id: String
    public let kind: UsageWindowKind
    public let startedAt: Date
    public let resetsAt: Date
    public let peakUtilization: Double
    public let epochId: String
    public let planName: String?
    /// A plan change ended this window early. Its peak was measured against the *old* plan's
    /// limit, so it isn't comparable with the windows after it.
    public let truncatedByPlanChange: Bool
    /// Recording stopped well before the window closed, so the peak likely understates it —
    /// utilization climbs until the reset, and nobody was watching at the end.
    public let coverageIsPartial: Bool
    /// Still accumulating, so its bar hasn't finished growing.
    public let isRunning: Bool

    /// Whether the peak can be read as this window's final number against a stable limit.
    public var isDefinitive: Bool {
        !isRunning && !coverageIsPartial && !truncatedByPlanChange
    }

    public var caveat: String? {
        if isRunning { return "still running" }
        if truncatedByPlanChange { return "ended by a plan change" }
        if coverageIsPartial { return "partly recorded" }
        return nil
    }
}

/// A plan change, for annotating a chart's time axis.
public struct HistoryEpochBoundary: Identifiable {
    public let id: String
    public let date: Date
    public let fromPlanName: String?
    public let toPlanName: String?

    public var label: String {
        switch (fromPlanName, toPlanName) {
        case let (from?, to?): return "\(from) → \(to)"
        case let (nil, to?): return "Changed to \(to)"
        default: return "Plan changed"
        }
    }
}

/// One sample on a continuous-time chart. `seriesId` restarts at every window reset and every
/// plan change, so a chart grouping on it draws separate lines rather than one that slides
/// across boundaries it shouldn't cross.
public struct HistoryTimelinePoint: Identifiable {
    public let id: String
    public let date: Date
    public let percent: Double
    public let seriesId: String
    public let epochId: String
}

/// A run of consecutive windows recorded under one plan.
public struct HistoryEpochGroup: Identifiable {
    public let epochId: String
    public let planName: String?
    public var windows: [HistoryWindow]

    public var id: String { epochId }

    public var startedAt: Date? { windows.first?.startedAt }
    public var endedAt: Date? { windows.last?.resetsAt }

    /// Mean peak of the windows in this group whose numbers can be taken at face value. Scoped
    /// to the group because utilization is a fraction of a plan-specific limit — averaging
    /// across a plan change would produce a figure that describes neither plan.
    public var averagePeak: Double? {
        let definitive = windows.filter(\.isDefinitive)
        guard !definitive.isEmpty else { return nil }
        return definitive.reduce(0) { $0 + $1.peakUtilization } / Double(definitive.count)
    }

    /// e.g. "14 Aug – 18 Aug · 87% average peak"
    public var caption: String? {
        var parts: [String] = []
        if let range = UsageFormatting.rangeCaption(from: startedAt, to: endedAt) {
            parts.append(range)
        }
        if let averagePeak {
            parts.append("\(Int(averagePeak.rounded()))% average peak")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Everything the history UI needs, derived in one pass off the main thread.
public struct UsageHistorySummary {
    public let windows: [HistoryWindow]
    public let epochs: [PlanEpoch]
    public let boundaries: [HistoryEpochBoundary]
    public let samples: [UsageSample]
    /// How far back the raw samples reach — shorter than the window history, since samples are
    /// trimmed to a retention window and the aggregates aren't.
    public let sampleWindow: TimeInterval

    public var isEmpty: Bool { windows.isEmpty }

    public func windows(_ kind: UsageWindowKind, limit: Int? = nil) -> [HistoryWindow] {
        let matching = windows.filter { $0.kind == kind }
        guard let limit, matching.count > limit else { return matching }
        return Array(matching.suffix(limit))
    }

    public func timeline(_ kind: UsageWindowKind) -> [HistoryTimelinePoint] {
        samples.compactMap { sample in
            let percent: Double?
            let resetsAt: Date?
            switch kind {
            case .fiveHour:
                percent = sample.fiveHourPercent
                resetsAt = sample.fiveHourResetsAt
            case .sevenDay:
                percent = sample.sevenDayPercent
                resetsAt = sample.sevenDayResetsAt
            }
            guard let percent, let resetsAt else { return nil }
            return HistoryTimelinePoint(
                id: "\(kind.rawValue)-\(sample.recordedAt.timeIntervalSince1970)",
                date: sample.recordedAt,
                percent: percent,
                seriesId: "\(sample.epochId)/\(Int(resetsAt.timeIntervalSince1970))",
                epochId: sample.epochId)
        }
    }

    /// Windows split into runs of one plan each, oldest first.
    ///
    /// Charts render a group at a time rather than one continuous axis: utilization is a
    /// percentage of a plan-specific limit, so bars either side of a plan change are measured
    /// against different denominators and can't be compared. With no plan change recorded —
    /// the usual case — this is a single group and the split is invisible.
    public func groupedWindows(_ kind: UsageWindowKind, limit: Int? = nil)
        -> [HistoryEpochGroup]
    {
        var groups: [HistoryEpochGroup] = []
        for window in windows(kind, limit: limit) {
            if groups.last?.epochId == window.epochId {
                groups[groups.count - 1].windows.append(window)
            } else {
                groups.append(
                    HistoryEpochGroup(
                        epochId: window.epochId, planName: window.planName, windows: [window]))
            }
        }
        return groups
    }

    /// The caveats a chart of `groups` needs stated under it, or `nil` when there are none.
    public func caveats(for groups: [HistoryEpochGroup]) -> String? {
        var parts: [String] = []
        if groups.contains(where: { $0.windows.contains { !$0.isDefinitive } }) {
            parts.append("Faded bars are still running or were only partly recorded.")
        }
        if groups.count > 1 {
            parts.append(
                "Percentages are of a plan-specific limit, so bars either side of a plan change "
                    + "aren't comparable.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - Loading

    /// Reads history off disk. Synchronous file I/O — call it off the main thread.
    /// - Parameter sampleWindow: how far back to read raw samples, or `nil` to skip them —
    ///   the sparkline needs only the window aggregates and is loaded on every popover open.
    public static func load(
        organizationId: String,
        sampleWindow: TimeInterval? = 48 * 60 * 60,
        now: Date = Date()
    ) -> UsageHistorySummary {
        let epochs = UsageHistoryStore.loadEpochs(organizationId: organizationId)
        let records = UsageHistoryStore.loadWindows(organizationId: organizationId)
        let samples =
            sampleWindow.map {
                UsageHistoryStore.loadSamples(
                    organizationId: organizationId, since: now.addingTimeInterval(-$0))
            } ?? []

        let planNames = Dictionary(
            epochs.map { ($0.id, $0.planName) }, uniquingKeysWith: { first, _ in first })

        let windows = records.map { record -> HistoryWindow in
            let isRunning = record.resetsAt > now && !record.truncatedByPlanChange
            // 5% of the window: ~15 minutes of a 5-hour session, which any polling interval
            // comfortably beats, and ~8 hours of a week, which background refresh usually does.
            let tolerance = record.kind.duration * 0.05
            return HistoryWindow(
                id: record.key,
                kind: record.kind,
                startedAt: record.resetsAt.addingTimeInterval(-record.kind.duration),
                resetsAt: record.resetsAt,
                peakUtilization: record.peakUtilization,
                epochId: record.epochId,
                planName: planNames[record.epochId] ?? nil,
                truncatedByPlanChange: record.truncatedByPlanChange,
                coverageIsPartial: !isRunning && !record.truncatedByPlanChange
                    && record.lastSeen < record.resetsAt.addingTimeInterval(-tolerance),
                isRunning: isRunning)
        }

        var boundaries: [HistoryEpochBoundary] = []
        for (index, epoch) in epochs.enumerated() {
            guard let endedAt = epoch.endedAt, index + 1 < epochs.count else { continue }
            boundaries.append(
                HistoryEpochBoundary(
                    id: epoch.id,
                    date: endedAt,
                    fromPlanName: epoch.planName,
                    toPlanName: epochs[index + 1].planName))
        }

        return UsageHistorySummary(
            windows: windows,
            epochs: epochs,
            boundaries: boundaries,
            samples: samples,
            sampleWindow: sampleWindow ?? 0)
    }

    public static let empty = UsageHistorySummary(
        windows: [], epochs: [], boundaries: [], samples: [], sampleWindow: 0)
}
