import Foundation

/// How the 5-hour usage is shown in the menu bar status item.
enum MenuBarDisplayStyle: String, CaseIterable, Identifiable {
    case ring
    case ringAndPercent
    case percentOnly
    case percentStackedOverReset

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ring: return "Ring"
        case .ringAndPercent: return "Ring + Percentage"
        case .percentOnly: return "Percentage"
        case .percentStackedOverReset: return "Percentage + Reset Time"
        }
    }

    static let defaultsKey = "menuBarDisplayStyle"

    /// Read directly from `UserDefaults` for `StatusItemController` (AppKit, no `@AppStorage`)
    /// — uses the same key `SettingsView`'s `@AppStorage` writes to.
    static var current: MenuBarDisplayStyle {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(MenuBarDisplayStyle.init(rawValue:))
            ?? .ringAndPercent
    }
}
