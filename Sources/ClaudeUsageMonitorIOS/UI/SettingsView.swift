import SwiftUI

struct SettingsView: View {
    let organizationName: String
    let organizationId: String
    let loggedInAt: Date?
    let onSignOut: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Account") {
                LabeledRow(label: "Organization", value: organizationName)
                LabeledRow(label: "Organization ID", value: organizationId)
                if let loggedInAt {
                    LabeledRow(
                        label: "Logged in",
                        value: loggedInAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    onSignOut()
                    dismiss()
                }
            }

            Section {
                HStack {
                    Spacer()
                    Text(versionString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(shortVersion) (\(build))"
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
