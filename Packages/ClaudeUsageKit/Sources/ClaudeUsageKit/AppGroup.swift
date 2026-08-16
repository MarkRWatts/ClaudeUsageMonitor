import Foundation

/// The App Group shared between the iOS app and its widget extension — used both as the App
/// Group container identifier and as the Keychain access group. Not used on macOS: the mac
/// app and widget extension don't exist in the same App Group, so `CredentialStore.accessGroup`
/// stays `nil` there.
public enum AppGroup {
    public static let identifier = "group.com.markwatts.ClaudeUsageMonitor"
}
