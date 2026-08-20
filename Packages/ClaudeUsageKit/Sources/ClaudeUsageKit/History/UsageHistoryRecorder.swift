import Foundation

/// Records one poll of the usage endpoint into history.
///
/// The usage API has no history of its own — it reports only the current numbers — so the apps
/// have to be their own historian. Every caller that has just fetched a fresh `UsageResponse`
/// funnels through here.
public enum UsageHistoryRecorder {
    /// Full-resolution samples are only the detail layer behind the window aggregates, which are
    /// kept indefinitely. A week is well past what any chart would show.
    private static let sampleRetention: TimeInterval = 7 * 24 * 60 * 60
    private static let maintenanceInterval: TimeInterval = 6 * 60 * 60

    private static var lastMaintenance: Date?

    /// - Parameters:
    ///   - organization: best-effort — every caller fetches it with `try?`, so it's routinely
    ///     `nil` after a network blip. A `nil` never ends an epoch.
    ///   - performMaintenance: pass `true` from the host apps, `false` from the widget
    ///     extension, which has a tight execution budget and shouldn't be rewriting log files.
    public static func record(
        usage: UsageResponse,
        organization: Organization?,
        organizationId: String,
        performMaintenance: Bool = false
    ) {
        let now = Date()

        UsageHistoryStore.apply(organizationId: organizationId) { state in
            let planChanged = resolveEpoch(&state, organization: organization, now: now)
            guard let epochId = state.epochs.last(where: { $0.isOpen })?.id else {
                return UsageHistoryStore.Mutation()
            }

            var mutation = UsageHistoryStore.Mutation()
            mutation.closedWindows = closeFinishedWindows(
                &state, usage: usage, planChanged: planChanged)

            if let resetsAt = usage.fiveHour?.resetsAt {
                touchWindow(
                    &state, kind: .fiveHour, resetsAt: resetsAt,
                    utilization: usage.fiveHour?.utilization ?? 0, epochId: epochId, now: now)
            }
            if let resetsAt = usage.sevenDay?.resetsAt {
                touchWindow(
                    &state, kind: .sevenDay, resetsAt: resetsAt,
                    utilization: usage.sevenDay?.utilization ?? 0, epochId: epochId, now: now)
            }

            mutation.sample = UsageSample(
                recordedAt: now,
                epochId: epochId,
                fiveHourPercent: usage.fiveHour?.utilization,
                fiveHourResetsAt: usage.fiveHour?.resetsAt,
                sevenDayPercent: usage.sevenDay?.utilization,
                sevenDayResetsAt: usage.sevenDay?.resetsAt,
                spendPercent: usage.spend?.percent,
                spendUsed: usage.spend?.used,
                spendLimit: usage.spend?.limit)
            return mutation
        }

        if performMaintenance { runMaintenanceIfDue(organizationId: organizationId, now: now) }
    }

    // MARK: - Epochs

    /// Returns whether this poll crossed a plan boundary.
    ///
    /// The boundary is detected on `capabilities`, not on the utilization dropping to zero: an
    /// upgrade resets every limit, which in the raw numbers looks exactly like a window rolling
    /// over normally, except the new numbers are measured against a different limit.
    private static func resolveEpoch(
        _ state: inout UsageHistoryStore.State, organization: Organization?, now: Date
    ) -> Bool {
        guard let index = state.epochs.lastIndex(where: { $0.isOpen }) else {
            state.epochs.append(
                PlanEpoch(
                    id: UUID().uuidString,
                    startedAt: now,
                    capabilities: organization?.planCapabilities ?? [],
                    allCapabilities: organization?.capabilities ?? [],
                    planName: organization?.planName))
            return false
        }

        guard let organization, !organization.planCapabilities.isEmpty else { return false }

        if state.epochs[index].isProvisional {
            // The organization fetch had failed when this epoch opened; filling it in now is
            // learning what the plan always was, not a change of plan.
            state.epochs[index].capabilities = organization.planCapabilities
            state.epochs[index].allCapabilities = organization.capabilities
            state.epochs[index].planName = organization.planName
            return false
        }

        state.epochs[index].allCapabilities = organization.capabilities

        // Compared as sets: the endpoint makes no ordering guarantee.
        guard Set(state.epochs[index].capabilities) != Set(organization.planCapabilities) else {
            return false
        }

        state.epochs[index].endedAt = now
        state.epochs.append(
            PlanEpoch(
                id: UUID().uuidString,
                startedAt: now,
                capabilities: organization.planCapabilities,
                allCapabilities: organization.capabilities,
                planName: organization.planName))
        return true
    }

    // MARK: - Windows

    /// Closes every open window the incoming poll has moved past — a different `resets_at`, no
    /// active window at all, or a plan change, which ends all of them at once.
    private static func closeFinishedWindows(
        _ state: inout UsageHistoryStore.State, usage: UsageResponse, planChanged: Bool
    ) -> [UsageWindowRecord] {
        var closed: [UsageWindowRecord] = []
        state.openWindows.removeAll { window in
            let incoming: Date? =
                window.kind == .fiveHour ? usage.fiveHour?.resetsAt : usage.sevenDay?.resetsAt
            guard planChanged || incoming != window.resetsAt else { return false }
            var record = window
            if planChanged { record.truncatedByPlanChange = true }
            closed.append(record)
            return true
        }
        return closed
    }

    private static func touchWindow(
        _ state: inout UsageHistoryStore.State,
        kind: UsageWindowKind,
        resetsAt: Date,
        utilization: Double,
        epochId: String,
        now: Date
    ) {
        if let index = state.openWindows.firstIndex(where: {
            $0.kind == kind && $0.resetsAt == resetsAt && $0.epochId == epochId
        }) {
            state.openWindows[index].peakUtilization = max(
                state.openWindows[index].peakUtilization, utilization)
            state.openWindows[index].lastSeen = now
            state.openWindows[index].sampleCount += 1
        } else {
            state.openWindows.append(
                UsageWindowRecord(
                    kind: kind,
                    resetsAt: resetsAt,
                    peakUtilization: utilization,
                    firstSeen: now,
                    lastSeen: now,
                    sampleCount: 1,
                    epochId: epochId,
                    truncatedByPlanChange: false))
        }
    }

    // MARK: - Maintenance

    private static func runMaintenanceIfDue(organizationId: String, now: Date) {
        if let lastMaintenance, now.timeIntervalSince(lastMaintenance) < maintenanceInterval {
            return
        }
        lastMaintenance = now
        UsageHistoryStore.trimSamples(
            organizationId: organizationId, before: now.addingTimeInterval(-sampleRetention))
    }
}
