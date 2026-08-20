import Charts
import ClaudeUsageKit
import SwiftUI

/// Raw samples over real elapsed time — the sawtooth of usage climbing and resetting.
///
/// The line is broken into one series per window, so it never slides continuously across a
/// reset (or a plan change) as though usage had smoothly declined.
struct UsageTimelineChart: View {
    let points: [HistoryTimelinePoint]
    let boundaries: [HistoryEpochBoundary]
    var height: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Usage", point.percent),
                        series: .value("Window", point.seriesId))
                        .foregroundStyle(.tint)
                        .interpolationMethod(.monotone)
                }

                ForEach(visibleBoundaries) { boundary in
                    RuleMark(x: .value("Time", boundary.date))
                        .foregroundStyle(.primary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .chartYScale(domain: 0...100)
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
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    // Minutes included so a 24-hour locale renders "Wed, 04:00" rather than
                    // "Wed, 04", which reads as a date.
                    AxisValueLabel(
                        format: .dateTime.weekday(.abbreviated).hour().minute())
                }
            }
            .frame(height: height)

            // The rule marks are labelled here rather than annotated onto the chart: an
            // annotation above the plot area gets clipped at these heights, and Charts can't
            // resolve that overflow before iOS 17 / macOS 14.
            ForEach(visibleBoundaries) { boundary in
                Text("\(boundary.label) · \(boundary.date, format: .dateTime.day().month(.abbreviated))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Only boundaries inside the plotted range — a rule mark outside it stretches the axis to
    /// reach a date with no data on it.
    private var visibleBoundaries: [HistoryEpochBoundary] {
        guard let first = points.first?.date, let last = points.last?.date else { return [] }
        return boundaries.filter { $0.date >= first && $0.date <= last }
    }
}
