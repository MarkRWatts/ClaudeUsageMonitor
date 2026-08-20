import Foundation

/// Advisory whole-file lock (`flock`) serialising history writes across processes — on iOS the
/// app and the widget extension both record into the same App Group container.
///
/// The lock lives in its own file rather than on one of the data files, because the small
/// mutable files are replaced by atomic write (a rename), which would drop a lock held on the
/// old inode.
final class FileLock {
    private let descriptor: Int32

    init?(url: URL) {
        let fd = open(url.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else {
            DebugLog.write("FileLock open failed: \(String(cString: strerror(errno)))")
            return nil
        }
        descriptor = fd
    }

    deinit { close(descriptor) }

    func withExclusiveAccess<T>(_ body: () throws -> T) rethrows -> T? {
        guard flock(descriptor, LOCK_EX) == 0 else { return nil }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}
