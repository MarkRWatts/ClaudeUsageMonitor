import Foundation

public enum UsageFormatting {
    public static func resetsSubtitle(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        let isToday = Calendar.current.isDateInToday(date)
        formatter.dateFormat = isToday ? "'at' h:mm a" : "EEE 'at' h:mm a"
        return "Resets " + formatter.string(from: date)
    }
}
