import Foundation

public enum DebugLog {
    private static let path: String = {
        #if os(macOS)
        return "/tmp/claude_usage_monitor_debug.log"
        #else
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier)
        let directory = containerURL ?? FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first!
        return directory.appendingPathComponent("claude_usage_monitor_debug.log").path
        #endif
    }()

    public static func write(_ message: String) {
        let line = "\(Date()): \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: path) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
