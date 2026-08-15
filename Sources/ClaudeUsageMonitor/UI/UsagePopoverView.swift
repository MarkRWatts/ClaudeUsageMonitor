import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var store: UsageStore
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Claude Usage")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            UsageBarRow(
                title: "5-Hour Session",
                percent: store.fiveHourPercent,
                subtitle: UsageFormatting.resetsSubtitle(store.fiveHourResetsAt))

            UsageBarRow(
                title: "Weekly (All Models)",
                percent: store.sevenDayPercent,
                subtitle: UsageFormatting.resetsSubtitle(store.sevenDayResetsAt))

            UsageBarRow(
                title: "Usage Credits",
                percent: store.spendPercent,
                subtitle: "\(store.spendUsedFormatted) of \(store.spendLimitFormatted)")

            if let lastUpdated = store.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}
