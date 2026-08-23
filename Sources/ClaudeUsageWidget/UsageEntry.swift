import ClaudeUsageKit
import WidgetKit

struct UsageEntry: TimelineEntry {
    let date: Date
    let fiveHourPercent: Double
    let fiveHourResetsAt: Date?
    let sevenDayPercent: Double
    let sevenDayResetsAt: Date?
    /// `nil` when the account's plan doesn't meter Fable separately — the row is hidden.
    let fableWeeklyPercent: Double?
    let spendPercent: Double
    let spendUsedFormatted: String
    let spendLimitFormatted: String
    let planName: String?
    let isSignedIn: Bool
    let isStale: Bool

    static func from(
        response: UsageResponse, planName: String?, date: Date, isStale: Bool
    ) -> UsageEntry {
        UsageEntry(
            date: date,
            fiveHourPercent: response.fiveHour?.utilization ?? 0,
            fiveHourResetsAt: response.fiveHour?.resetsAt,
            sevenDayPercent: response.sevenDay?.utilization ?? 0,
            sevenDayResetsAt: response.sevenDay?.resetsAt,
            fableWeeklyPercent: response.fableWeekly?.utilization,
            spendPercent: response.spend?.percent ?? 0,
            spendUsedFormatted: response.spend?.used?.formatted ?? "—",
            spendLimitFormatted: response.spend?.limit?.formatted ?? "—",
            planName: planName,
            isSignedIn: true,
            isStale: isStale)
    }

    static let signedOut = UsageEntry(
        date: Date(), fiveHourPercent: 0, fiveHourResetsAt: nil, sevenDayPercent: 0,
        sevenDayResetsAt: nil, fableWeeklyPercent: nil, spendPercent: 0,
        spendUsedFormatted: "—", spendLimitFormatted: "—", planName: nil, isSignedIn: false,
        isStale: false)

    static let placeholder = UsageEntry(
        date: Date(), fiveHourPercent: 42, fiveHourResetsAt: Date().addingTimeInterval(3600),
        sevenDayPercent: 61, sevenDayResetsAt: Date().addingTimeInterval(86400 * 3),
        fableWeeklyPercent: 27, spendPercent: 18, spendUsedFormatted: "$9.00",
        spendLimitFormatted: "$50.00", planName: "Max", isSignedIn: true, isStale: false)
}
