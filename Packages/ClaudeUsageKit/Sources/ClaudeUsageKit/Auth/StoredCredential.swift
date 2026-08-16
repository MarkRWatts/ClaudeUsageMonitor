import Foundation

public struct StoredCredential: Codable {
    public let cookieHeader: String
    public let organizationId: String
    public let organizationName: String
    public let loggedInAt: Date

    public init(
        cookieHeader: String, organizationId: String, organizationName: String, loggedInAt: Date
    ) {
        self.cookieHeader = cookieHeader
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.loggedInAt = loggedInAt
    }
}
