import Foundation

/// On-disk usage history.
///
/// Four files per organization:
/// - `samples.ndjson` — append-only raw polls, the detail layer, trimmed to a retention window.
/// - `windows.ndjson` — append-only completed windows, the durable layer, kept indefinitely
///   (a few hundred bytes per 5-hour window).
/// - `open-windows.json` — the at-most-two windows still accumulating. Small and rewritten on
///   every poll, which is why it's separate from the closed log.
/// - `epochs.json` — the plan epochs, rewritten only when a plan changes.
public enum UsageHistoryStore {
    private static let samplesFile = "samples.ndjson"
    private static let closedWindowsFile = "windows.ndjson"
    private static let openWindowsFile = "open-windows.json"
    private static let epochsFile = "epochs.json"
    private static let lockFile = ".lock"

    /// The mutable state a recording pass reads and writes back.
    public struct State {
        public var openWindows: [UsageWindowRecord]
        public var epochs: [PlanEpoch]
    }

    /// What a recording pass wants appended to the log files.
    public struct Mutation {
        public var sample: UsageSample?
        public var closedWindows: [UsageWindowRecord]

        public init(sample: UsageSample? = nil, closedWindows: [UsageWindowRecord] = []) {
            self.sample = sample
            self.closedWindows = closedWindows
        }
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

    // MARK: - Recording

    /// Reads the mutable state, hands it to `body`, and persists both the state and whatever
    /// `body` returns — all under one cross-process lock, so a concurrent widget refresh can't
    /// interleave with the app's and lose a window.
    @discardableResult
    public static func apply(organizationId: String, _ body: (inout State) -> Mutation) -> Bool {
        guard let directory = HistoryContainer.directory(organizationId: organizationId),
            let lock = FileLock(url: directory.appendingPathComponent(lockFile))
        else { return false }

        let result = lock.withExclusiveAccess { () -> Bool in
            var state = State(
                openWindows: readJSON(
                    [UsageWindowRecord].self, at: directory.appendingPathComponent(openWindowsFile))
                    ?? [],
                epochs: readJSON(
                    [PlanEpoch].self, at: directory.appendingPathComponent(epochsFile)) ?? [])

            let mutation = body(&state)

            writeJSON(state.openWindows, to: directory.appendingPathComponent(openWindowsFile))
            writeJSON(state.epochs, to: directory.appendingPathComponent(epochsFile))
            if !mutation.closedWindows.isEmpty {
                appendLines(
                    mutation.closedWindows, to: directory.appendingPathComponent(closedWindowsFile))
            }
            if let sample = mutation.sample {
                appendLines([sample], to: directory.appendingPathComponent(samplesFile))
            }
            return true
        }
        return result ?? false
    }

    // MARK: - Reading

    /// Every window seen, closed and open, merged by key and ordered oldest first. Duplicate
    /// closed records — two processes can both close the same window — collapse here rather
    /// than at write time, which is also how a cross-device merge would work.
    public static func loadWindows(organizationId: String) -> [UsageWindowRecord] {
        withDirectory(organizationId) { directory in
            let closed = readLines(
                UsageWindowRecord.self, at: directory.appendingPathComponent(closedWindowsFile))
            let open =
                readJSON(
                    [UsageWindowRecord].self, at: directory.appendingPathComponent(openWindowsFile))
                ?? []

            var byKey: [String: UsageWindowRecord] = [:]
            for record in closed + open {
                byKey[record.key] = byKey[record.key].map { $0.merged(with: record) } ?? record
            }
            // `firstSeen` breaks ties: a plan change can leave two windows sharing a reset
            // time, and a chart needs them in a stable order.
            return byKey.values.sorted {
                ($0.resetsAt, $0.firstSeen) < ($1.resetsAt, $1.firstSeen)
            }
        } ?? []
    }

    public static func loadSamples(organizationId: String, since: Date? = nil) -> [UsageSample] {
        withDirectory(organizationId) { directory in
            let samples = readLines(
                UsageSample.self, at: directory.appendingPathComponent(samplesFile))
            guard let since else { return samples }
            return samples.filter { $0.recordedAt >= since }
        } ?? []
    }

    public static func loadEpochs(organizationId: String) -> [PlanEpoch] {
        withDirectory(organizationId) { directory in
            readJSON([PlanEpoch].self, at: directory.appendingPathComponent(epochsFile)) ?? []
        } ?? []
    }

    // MARK: - Maintenance

    /// Drops samples older than `cutoff`. The window records they roll up into are kept, so this
    /// loses resolution, not history.
    public static func trimSamples(organizationId: String, before cutoff: Date) {
        withDirectory(organizationId) { directory in
            let url = directory.appendingPathComponent(samplesFile)
            let samples = readLines(UsageSample.self, at: url)
            let retained = samples.filter { $0.recordedAt >= cutoff }
            guard retained.count < samples.count else { return }
            replaceLines(retained, at: url)
        }
    }

    /// Deletes every recorded file for this organization. The directory itself stays, so a
    /// concurrent widget refresh holding the lock file doesn't end up writing into a directory
    /// that no longer exists.
    public static func clear(organizationId: String) {
        withDirectory(organizationId) { directory in
            for name in [samplesFile, closedWindowsFile, openWindowsFile, epochsFile] {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
            }
        }
    }

    // MARK: - File helpers

    private static func withDirectory<T>(_ organizationId: String, _ body: (URL) -> T) -> T? {
        guard let directory = HistoryContainer.directory(organizationId: organizationId),
            let lock = FileLock(url: directory.appendingPathComponent(lockFile))
        else { return nil }
        return lock.withExclusiveAccess { body(directory) }
    }

    private static func readJSON<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            DebugLog.write("UsageHistoryStore read \(url.lastPathComponent) failed: \(error)")
            return nil
        }
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) {
        do {
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            DebugLog.write("UsageHistoryStore write \(url.lastPathComponent) failed: \(error)")
        }
    }

    private static func appendLines<T: Encodable>(_ values: [T], to url: URL) {
        let data = encodeLines(values)
        guard !data.isEmpty else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else {
            DebugLog.write("UsageHistoryStore append \(url.lastPathComponent): no handle")
            return
        }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            DebugLog.write("UsageHistoryStore append \(url.lastPathComponent) failed: \(error)")
        }
    }

    /// Writes an empty file when `values` is empty, rather than leaving the old contents — a
    /// gap of more than the retention window makes every sample stale at once.
    private static func replaceLines<T: Encodable>(_ values: [T], at url: URL) {
        do {
            try encodeLines(values).write(to: url, options: .atomic)
        } catch {
            DebugLog.write("UsageHistoryStore replace \(url.lastPathComponent) failed: \(error)")
        }
    }

    private static func encodeLines<T: Encodable>(_ values: [T]) -> Data {
        var data = Data()
        for value in values {
            guard let encoded = try? encoder.encode(value) else { continue }
            data.append(encoded)
            data.append(0x0A)
        }
        return data
    }

    /// Skips lines that don't decode rather than failing the whole read — a write interrupted
    /// by the widget extension being killed mid-append can leave a torn final line.
    private static func readLines<T: Decodable>(_ type: T.Type, at url: URL) -> [T] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return data.split(separator: 0x0A).compactMap { line in
            try? decoder.decode(type, from: Data(line))
        }
    }
}
