import BackgroundTasks
import Foundation

/// Requests a periodic background refresh so the widget has reasonably fresh data even when
/// the app itself isn't opened often. iOS decides the actual run time — `minimumInterval` is
/// just the earliest we'll ask for, mirroring the spirit of the mac app's 180s background
/// timer within what `BGTaskScheduler` actually permits.
enum BackgroundRefreshScheduler {
    static let identifier = "com.markwatts.ClaudeUsageMonitor.ios.refresh"
    private static let minimumInterval: TimeInterval = 15 * 60

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handle(task: refreshTask)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGAppRefreshTask) {
        // Reschedule the next run up front — BGTaskScheduler only fires a registered task once
        // per submission.
        schedule()

        let refreshTask = Task {
            let outcome = await UsageRefresher.refresh(store: nil)
            task.setTaskCompleted(success: outcome != .failure)
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }
    }
}
