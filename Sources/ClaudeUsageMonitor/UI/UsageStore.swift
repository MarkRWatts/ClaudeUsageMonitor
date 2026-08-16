import Combine
import Foundation

final class UsageStore: ObservableObject {
    @Published var fiveHourPercent: Double = 0
    @Published var fiveHourResetsAt: Date?
    @Published var sevenDayPercent: Double = 0
    @Published var sevenDayResetsAt: Date?
    @Published var spendPercent: Double = 0
    @Published var spendUsedFormatted: String = "—"
    @Published var spendLimitFormatted: String = "—"
    @Published var lastUpdated: Date?
    @Published var planName: String?

    func apply(_ response: UsageResponse) {
        fiveHourPercent = Double(response.fiveHour?.utilization ?? 0)
        fiveHourResetsAt = response.fiveHour?.resetsAt
        sevenDayPercent = Double(response.sevenDay?.utilization ?? 0)
        sevenDayResetsAt = response.sevenDay?.resetsAt
        spendPercent = Double(response.spend?.percent ?? 0)
        spendUsedFormatted = response.spend?.used?.formatted ?? "—"
        spendLimitFormatted = response.spend?.limit?.formatted ?? "—"
        lastUpdated = Date()
    }

    func reset() {
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
