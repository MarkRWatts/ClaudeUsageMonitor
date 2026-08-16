import Foundation

public enum UsageAPIError: Error {
    case unauthorized
    case unexpectedStatus(Int)
    case noOrganization
}

public enum UsageAPIClient {
    private static let baseURL = URL(string: "https://claude.ai/api")!

    private static var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let whole = ISO8601DateFormatter()
        whole.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = fractional.date(from: string) ?? whole.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unrecognized date format: \(string)")
        }
        return decoder
    }()

    private static func request(path: String, cookieHeader: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UsageAPIError.unexpectedStatus(-1)
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            DebugLog.write("\(request.url?.path ?? "") -> \(http.statusCode) (unauthorized)")
            throw UsageAPIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            DebugLog.write(
                "\(request.url?.path ?? "") -> \(http.statusCode), body: \(String(data: data.prefix(500), encoding: .utf8) ?? "<binary>")"
            )
            throw UsageAPIError.unexpectedStatus(http.statusCode)
        }
        return data
    }

    public static func fetchOrganization(cookieHeader: String) async throws -> Organization {
        let data = try await send(request(path: "organizations", cookieHeader: cookieHeader))
        let organizations = try jsonDecoder.decode([Organization].self, from: data)
        guard let first = organizations.first else { throw UsageAPIError.noOrganization }
        return first
    }

    public static func fetchUsage(_ credential: StoredCredential) async throws -> UsageResponse {
        let data = try await send(
            request(
                path: "organizations/\(credential.organizationId)/usage",
                cookieHeader: credential.cookieHeader))
        do {
            return try jsonDecoder.decode(UsageResponse.self, from: data)
        } catch {
            DebugLog.write("fetchUsage decode failed: \(error)")
            throw error
        }
    }
}
