import Charts
import ClaudeUsageKit
import SwiftUI

/// Peak usage of each limit window, one bar apiece, oldest on the left.
///
/// Bars are categorical rather than laid out on a time axis: this answers "how close to the cap
/// do I usually get", where even spacing reads better than the ragged gaps of real elapsed time.
/// `UsageTimelineChart` is the one that shows actual time.
///
/// Callers pass windows from a single plan epoch — utilization is a percentage of a
/// plan-specific limit, so bars either side of a plan change don't belong on one axis.
struct SessionPeaksChart: View {
    let windows: [HistoryWindow]

    var body: some View {
        Chart(windows) { window in
            BarMark(
                x: .value("Window", window.id),
                y: .value("Peak", window.peakUtilization))
                .foregroundStyle(UsageSeverity.color(for: window.peakUtilization))
                // Faded means "don't read this bar as a finished number": either it's still
                // climbing, or nothing was recording as it closed.
                .opacity(window.isDefinitive ? 1 : 0.45)
                .cornerRadius(2)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = value.as(Int.self) {
                        Text("\(percent)%")
                    }
                }
            }
        }
    }
}
