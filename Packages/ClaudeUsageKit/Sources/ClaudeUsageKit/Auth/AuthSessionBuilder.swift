import Foundation

/// Turns the cookies captured from an embedded claude.ai login `WKWebView` into a validated,
/// ready-to-save `StoredCredential`. Shared between the mac (`NSWindow`-hosted) and iOS
/// (`UIViewRepresentable`-hosted) login flows — everything except the WebView chrome itself.
public enum AuthSessionBuilder {
    public enum BuildError: Error {
        /// No claude.ai session cookies present yet — not a failure, just means the user
        /// hasn't finished logging in in the embedded WebView. Callers should treat this the
        /// same as any other error here: keep polling, don't surface it to the user.
        case noSessionCookies
    }

    public static func credential(fromCookies cookies: [HTTPCookie]) async throws -> StoredCredential {
        let claudeCookies = cookies.filter { $0.domain.hasSuffix("claude.ai") }
        guard !claudeCookies.isEmpty else { throw BuildError.noSessionCookies }

        let cookieHeader = claudeCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        let organization = try await UsageAPIClient.fetchOrganization(cookieHeader: cookieHeader)
        return StoredCredential(
            cookieHeader: cookieHeader,
            organizationId: organization.uuid,
            organizationName: organization.name,
            loggedInAt: Date())
    }
}
