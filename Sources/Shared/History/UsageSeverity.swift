import SwiftUI

enum UsageSeverity {
    /// Matches the thresholds the current-usage bars use, so a bar means the same thing
    /// wherever it appears.
    static func color(for percent: Double) -> Color {
        switch percent {
        case ..<70: return .green
        case ..<90: return .orange
        default: return .red
        }
    }
}
