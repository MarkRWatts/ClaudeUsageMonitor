import ClaudeUsageKit
import SwiftUI
import WidgetKit

struct ClaudeUsageWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumUsageView(entry: entry)
            // Lock Screen families are redacted by the system (generic bars/empty gauge) while
            // the device is locked and asleep/AOD-dimmed, since it can't know the content isn't
            // sensitive. `.unredacted()` opts back in to showing the real numbers there — a
            // usage percentage isn't worth hiding.
            case .accessoryCircular:
                CircularUsageView(entry: entry)
                    .unredacted()
            case .accessoryInline:
                Text(inlineText)
                    .unredacted()
            case .accessoryRectangular:
                RectangularUsageView(entry: entry)
                    .unredacted()
            default:
                SmallUsageView(entry: entry)
            }
        }
        .widgetBackground()
    }

    private var inlineText: String {
        entry.isSignedIn ? "Claude \(Int(entry.fiveHourPercent.rounded()))%" : "Claude: Sign in"
    }
}

private struct UsageRing: View {
    let percent: Double
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(percent, 0), 100)) / 100)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct SmallUsageView: View {
    let entry: UsageEntry

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                UsageRing(percent: entry.fiveHourPercent)
                Text("\(Int(entry.fiveHourPercent.rounded()))%")
                    .font(.system(size: 18, weight: .bold))
            }
            .frame(width: 56, height: 56)
            Text(entry.isSignedIn ? UsageFormatting.resetsSubtitle(entry.fiveHourResetsAt) : "Not Signed In")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding()
    }
}

private struct MediumUsageView: View {
    let entry: UsageEntry

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                UsageRing(percent: entry.fiveHourPercent, lineWidth: 7)
                VStack(spacing: 0) {
                    Text("\(Int(entry.fiveHourPercent.rounded()))%")
                        .font(.system(size: 16, weight: .bold))
                    Text("5h")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 8) {
                if entry.isSignedIn {
                    MiniBarRow(title: "Weekly", percent: entry.sevenDayPercent)
                    MiniBarRow(title: "Credits", percent: entry.spendPercent)
                    Text(UsageFormatting.resetsSubtitle(entry.fiveHourResetsAt))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not Signed In")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

private struct MiniBarRow: View {
    let title: String
    let percent: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.caption2)
                Spacer()
                Text("\(Int(percent.rounded()))%").font(.caption2).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(min(max(percent, 0), 100)) / 100)
                }
            }
            .frame(height: 4)
        }
    }
}

private struct CircularUsageView: View {
    let entry: UsageEntry

    var body: some View {
        Gauge(value: min(max(entry.fiveHourPercent, 0), 100), in: 0...100) {
            Text("5h")
        } currentValueLabel: {
            Text("\(Int(entry.fiveHourPercent.rounded()))")
        }
        .gaugeStyle(.accessoryCircular)
    }
}

private struct RectangularUsageView: View {
    let entry: UsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.isSignedIn {
                Text("5-Hour: \(Int(entry.fiveHourPercent.rounded()))%")
                    .font(.headline)
                Text(UsageFormatting.resetsSubtitle(entry.fiveHourResetsAt))
                    .font(.caption2)
            } else {
                Text("Claude Usage")
                    .font(.headline)
                Text("Not signed in")
                    .font(.caption2)
            }
        }
    }
}

extension View {
    @ViewBuilder
    fileprivate func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { Color(.systemBackground) }
        } else {
            background(Color(.systemBackground))
        }
    }
}
