import Foundation

/// How the 5-hour usage is shown in the menu bar status item.
enum MenuBarDisplayStyle: String, CaseIterable, Identifiable {
    case ring
    case ringAndPercent
    case percentOnly
    /// Existing rawValue kept as-is (it's already persisted) — this is the ring-included variant.
    case percentStackedOverReset
    case percentStackedOverResetNoRing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ring: return "Ring"
        case .ringAndPercent: return "Ring + Percentage"
        case .percentOnly: return "Percentage"
        case .percentStackedOverReset: return "Ring + Percentage + Reset Time"
        case .percentStackedOverResetNoRing: return "Percentage + Reset Time"
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
