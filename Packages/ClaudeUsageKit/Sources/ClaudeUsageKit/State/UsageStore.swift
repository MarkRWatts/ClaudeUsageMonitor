import Combine
import Foundation

public final class UsageStore: ObservableObject {
    @Published public var fiveHourPercent: Double = 0
    @Published public var fiveHourResetsAt: Date?
    @Published public var sevenDayPercent: Double = 0
    @Published public var sevenDayResetsAt: Date?
    @Published public var spendPercent: Double = 0
    @Published public var spendUsedFormatted: String = "—"
    @Published public var spendLimitFormatted: String = "—"
    @Published public var lastUpdated: Date?
    @Published public var planName: String?

    public init() {}

    public func apply(_ response: UsageResponse) {
        fiveHourPercent = Double(response.fiveHour?.utilization ?? 0)
        fiveHourResetsAt = response.fiveHour?.resetsAt
        sevenDayPercent = Double(response.sevenDay?.utilization ?? 0)
        sevenDayResetsAt = response.sevenDay?.resetsAt
        spendPercent = Double(response.spend?.percent ?? 0)
        spendUsedFormatted = response.spend?.used?.formatted ?? "—"
        spendLimitFormatted = response.spend?.limit?.formatted ?? "—"
        lastUpdated = Date()
    }

    public func reset() {
        fiveHourPercent = 0
        fiveHourResetsAt = nil
        sevenDayPercent = 0
        sevenDayResetsAt = nil
        spendPercent = 0
        spendUsedFormatted = "—"
        spendLimitFormatted = "—"
        lastUpdated = nil
        planName = nil
    }
}
