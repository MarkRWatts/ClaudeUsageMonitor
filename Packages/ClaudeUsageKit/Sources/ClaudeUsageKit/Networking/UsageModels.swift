import Foundation

public struct Organization: Codable {
    public let uuid: String
    public let name: String
    public let capabilities: [String]

    enum CodingKeys: String, CodingKey {
        case uuid, name, capabilities
    }

    public init(from decoder: Decoder) throws {
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

    /// The subset of `capabilities` that identifies the plan, sorted for stable comparison.
    ///
    /// The full array also carries unrelated feature flags, which come and go on Anthropic's
    /// own schedule — comparing all of them would read a flag flip as a plan change. Shares the
    /// reverse-engineered mapping above with `planName`, and shares its limitation: a brand new
    /// tier whose capability string isn't recognised here reads as no plan at all.
    public var planCapabilities: [String] {
        capabilities
            .filter { Self.planCapabilityNames[$0] != nil || $0.hasPrefix("claude_max_") }
            .sorted()
    }

    public var planName: String? {
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

public struct MoneyAmount: Codable {
    public let amountMinor: Int
    public let currency: String
    public let exponent: Int

    enum CodingKeys: String, CodingKey {
        case amountMinor = "amount_minor"
        case currency
        case exponent
    }

    /// e.g. 2000 minor units / 10^2 exponent -> 20.0
    public var value: Double { Double(amountMinor) / pow(10, Double(exponent)) }

    /// e.g. 2000 minor units / 10^2 exponent, "GBP" -> "£20.00"
    public var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) \(currency)"
    }
}

public struct FiveHourUsage: Codable {
    public let utilization: Double?
    public let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

public struct SevenDayUsage: Codable {
    public let utilization: Double?
    public let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

public struct SpendUsage: Codable {
    public let percent: Double?
    public let used: MoneyAmount?
    public let limit: MoneyAmount?
}

/// One entry of the `limits` array, the generalized form the endpoint moved to with the
/// Claude 5 launch. Model-scoped weekly limits (Fable's, notably) only appear here — their
/// old top-level `seven_day_<model>` spellings now come back null.
///
/// Every field is decoded tolerantly: this array is where Anthropic adds new limit kinds
/// first, and one unrecognised entry must not sink the whole usage response.
public struct UsageLimitEntry: Codable {
    public struct Scope: Codable {
        public struct Model: Codable {
            public let displayName: String?

            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
            }
        }

        public let model: Model?
    }

    public let kind: String?
    public let percent: Double?
    public let resetsAt: Date?
    public let scope: Scope?

    enum CodingKeys: String, CodingKey {
        case kind, percent, scope
        case resetsAt = "resets_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? nil
        percent = (try? container.decodeIfPresent(Double.self, forKey: .percent)) ?? nil
        scope = (try? container.decodeIfPresent(Scope.self, forKey: .scope)) ?? nil
        // `resets_at` has been observed as an ISO string, epoch seconds, and epoch
        // milliseconds — try the surrounding decoder's date strategy first, then epoch.
        if let date = (try? container.decodeIfPresent(Date.self, forKey: .resetsAt)) ?? nil {
            resetsAt = date
        } else if let epoch = (try? container.decodeIfPresent(Double.self, forKey: .resetsAt))
            ?? nil
        {
            resetsAt = Date(timeIntervalSince1970: epoch > 1e12 ? epoch / 1000 : epoch)
        } else {
            resetsAt = nil
        }
    }
}

public struct UsageResponse: Codable {
    public let fiveHour: FiveHourUsage?
    public let sevenDay: SevenDayUsage?
    public let spend: SpendUsage?
    public let limits: [UsageLimitEntry]?
    /// Pre-`limits` spelling of Fable's scoped weekly window; null on current payloads.
    public let sevenDayFable: SevenDayUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayFable = "seven_day_fable"
        case spend
        case limits
    }

    /// The Fable model's scoped weekly window, or `nil` when the account's plan doesn't
    /// meter Fable separately. Prefers the `limits` array, falling back to the legacy
    /// top-level field for payloads (or cached snapshots) that predate it.
    public var fableWeekly: SevenDayUsage? {
        if let entry = limits?.first(where: { entry in
            entry.kind == "weekly_scoped"
                && entry.scope?.model?.displayName?.range(
                    of: "fable", options: .caseInsensitive) != nil
        }), let percent = entry.percent {
            return SevenDayUsage(utilization: percent, resetsAt: entry.resetsAt)
        }
        return sevenDayFable
    }
}
