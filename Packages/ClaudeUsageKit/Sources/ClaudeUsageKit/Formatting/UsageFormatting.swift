import Foundation

public enum UsageFormatting {
    /// e.g. "14 Aug – 20 Aug", or just the one date when a range lands inside a single day.
    public static func rangeCaption(from start: Date?, to end: Date?) -> String? {
        guard let start, let end else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let first = formatter.string(from: start)
        let last = formatter.string(from: end)
        return first == last ? first : "\(first) – \(last)"
    }

    public static func resetsSubtitle(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        let isToday = Calendar.current.isDateInToday(date)
        formatter.dateFormat = isToday ? "'at' h:mm a" : "EEE 'at' h:mm a"
        return "Resets " + formatter.string(from: date)
    }
}
