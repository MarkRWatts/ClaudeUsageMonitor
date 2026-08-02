import Foundation

struct Organization: Decodable {
    let uuid: String
    let name: String
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
