import Foundation

/// Last-known-good usage snapshot, shared via the App Group so the widget extension can show
/// real numbers immediately (in `placeholder`/`getSnapshot`, and as a fallback if its own
/// network fetch fails) without waiting on its own request.
public enum UsageSnapshotCache {
    private static let key = "com.markwatts.ClaudeUsageMonitor.usageSnapshot"

    private struct Snapshot: Codable {
        let response: UsageResponse
        let planName: String?
        let fetchedAt: Date
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static func save(_ response: UsageResponse, planName: String?) {
        let snapshot = Snapshot(response: response, planName: planName, fetchedAt: Date())
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    public static func load() -> (response: UsageResponse, planName: String?, fetchedAt: Date)? {
        guard let data = defaults?.data(forKey: key),
            let snapshot = try? decoder.decode(Snapshot.self, from: data)
        else { return nil }
        return (snapshot.response, snapshot.planName, snapshot.fetchedAt)
    }
}
