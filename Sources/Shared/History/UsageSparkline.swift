import Charts
import ClaudeUsageKit
import SwiftUI

/// A few bars' worth of recent peaks, small enough to sit under a usage bar in the menu bar
/// popover without turning it into a dashboard.
struct UsageSparkline: View {
    let windows: [HistoryWindow]
    /// Tall enough that a bar well short of the limit still reads as a bar — the scale is
    /// fixed at 0–100 so the empty space above is the point.
    var height: CGFloat = 26

    var body: some View {
        Chart(windows) { window in
            BarMark(
                x: .value("Window", window.id),
                y: .value("Peak", window.peakUtilization),
                width: .ratio(0.6))
                .foregroundStyle(UsageSeverity.color(for: window.peakUtilization))
                .opacity(window.isDefinitive ? 1 : 0.45)
                .cornerRadius(1)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: height)
    }
}
