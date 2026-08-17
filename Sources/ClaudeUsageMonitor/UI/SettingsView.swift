import ClaudeUsageKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    let organizationName: String
    let organizationId: String
    let loggedInAt: Date?
    let onSignOut: () -> Void
    let onQuit: () -> Void
    let onClose: () -> Void

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?
    @AppStorage(MenuBarDisplayStyle.defaultsKey) private var menuBarDisplayStyle = MenuBarDisplayStyle.ringAndPercent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 15, weight: .bold))

            GroupBox("Account") {
                VStack(alignment: .leading, spacing: 6) {
                    LabeledRow(label: "Organization", value: organizationName)
                    LabeledRow(label: "Organization ID", value: organizationId)
                    if let loggedInAt {
                        LabeledRow(
                            label: "Logged in",
                            value: loggedInAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("Current Limits") {
                VStack(alignment: .leading, spacing: 10) {
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
                }
                .padding(.vertical, 4)
            }

            GroupBox("Menu Bar") {
                Picker("Display", selection: $menuBarDisplayStyle) {
                    ForEach(MenuBarDisplayStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .labelsHidden()
                .padding(.vertical, 4)
            }

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(newValue)
                }

            if let launchAtLoginError {
                Text(launchAtLoginError)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }

            Divider()

            HStack {
                Button("Sign Out", role: .destructive) {
                    onSignOut()
                }
                Button("Quit App") {
                    onQuit()
                }
                Spacer()
                Button("Close") {
                    onClose()
                }
            }

            Text(versionString)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .frame(width: 320)
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(shortVersion) (\(build))"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Couldn't update: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 11))
    }
}
