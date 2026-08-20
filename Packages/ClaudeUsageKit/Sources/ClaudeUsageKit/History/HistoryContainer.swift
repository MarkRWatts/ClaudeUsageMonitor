import Foundation

/// Resolves the on-disk home for recorded usage history, keyed by organization so signing in
/// to a different account can't blend two accounts' numbers together.
///
/// On iOS this lives in the App Group container, so the app and the widget extension — which
/// fetches live data of its own, and is often the only process sampling while the phone sits
/// idle — record into the same files. macOS has no App Group (see `AppGroup`), and the mac app
/// is unsandboxed, so it uses Application Support.
enum HistoryContainer {
    private static let folderName = "UsageHistory"

    static func directory(organizationId: String) -> URL? {
        guard let root = rootDirectory() else { return nil }
        let url = root.appendingPathComponent(sanitize(organizationId), isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            DebugLog.write("HistoryContainer.directory failed: \(error)")
            return nil
        }
        return url
    }

    private static func rootDirectory() -> URL? {
        #if os(iOS)
            return FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
                .appendingPathComponent(folderName, isDirectory: true)
        #else
            return FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("ClaudeUsageMonitor", isDirectory: true)
                .appendingPathComponent(folderName, isDirectory: true)
        #endif
    }

    /// Organization ids are UUIDs, but they arrive from the network — a path separator sneaking
    /// into one would silently write outside the container.
    private static func sanitize(_ id: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scrubbed = String(
            id.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        return scrubbed.isEmpty ? "unknown" : scrubbed
    }
}
