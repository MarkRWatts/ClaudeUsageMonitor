import Foundation

struct Organization: Decodable {
    let uuid: String
    let name: String
    let capabilities: [String]

    enum CodingKeys: String, CodingKey {
        case uuid, name, capabilities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        name = try container.decode(String.self, forKey: .name)
        capabilities = try container.decodeIfPresent([String].self, forKey: .capabilities) ?? []
    }

    /// The API exposes plan as an opaque `capabilities` flag (e.g. "claude_pro"), not a
    /// human-readable field — this mapping is reverse-engineered and may not cover every
    /// plan variant (e.g. Max tier suffixes).
    private static let planCapabilityNames: [String: String] = [
        "claude_free": "Free",
        "claude_pro": "Pro",
        "claude_max": "Max",
        "claude_team": "Team",
        "claude_enterprise": "Enterprise",
    ]

    var planName: String? {
        for capability in capabilities {
            if let name = Self.planCapabilityNames[capability] {
                return name
            }
            if capability.hasPrefix("claude_max_") {
                let suffix = capability.dropFirst("claude_max_".count)
                return "Max \(suffix)"
            }
        }
        return nil
    }
}

struct MoneyAmount: Decodable {
    let amountMinor: Int
    let currency: String
    let exponent: Int

    enum CodingKeys: String, CodingKey {
        case amountMinor = "amount_minor"
        case currency
        case exponent
    }

    /// e.g. 2000 minor units / 10^2 exponent, "GBP" -> "£20.00"
    var formatted: String {
        let value = Double(amountMinor) / pow(10, Double(exponent))
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) \(currency)"
    }
}

struct FiveHourUsage: Decodable {
    let utilization: Double?
    let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct SevenDayUsage: Decodable {
    let utilization: Double?
    let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct SpendUsage: Decodable {
    let percent: Double?
    let used: MoneyAmount?
    let limit: MoneyAmount?
}

struct UsageResponse: Decodable {
    let fiveHour: FiveHourUsage?
    let sevenDay: SevenDayUsage?
    let spend: SpendUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case spend
    }
}
