import Foundation
import Security

public enum CredentialStore {
    private static let service = "com.markwatts.ClaudeUsageMonitor"
    private static let account = "claude-ai-session"

    /// Keychain access group shared with the widget extension via the App Group. `nil` on
    /// macOS (default) — there's no cross-process sharing to do there, and adding
    /// `kSecAttrAccessGroup` to the query dict when it isn't needed can itself cause Keychain
    /// errors on some setups. The iOS app and widget extension both set this to
    /// `AppGroup.identifier` before their first `load`/`save` call.
    public static var accessGroup: String?

    private static var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    public static func save(_ credential: StoredCredential) {
        guard let data = try? JSONEncoder().encode(credential) else { return }

        let query = baseQuery
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    public static func load() -> StoredCredential? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredCredential.self, from: data)
    }

    public static func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
