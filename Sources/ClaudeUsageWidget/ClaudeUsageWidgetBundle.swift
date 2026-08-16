import ClaudeUsageKit
import WidgetKit
import SwiftUI

@main
struct ClaudeUsageWidgetBundle: WidgetBundle {
    init() {
        CredentialStore.accessGroup = AppGroup.identifier
    }

    var body: some Widget {
        ClaudeUsageWidget()
    }
}
