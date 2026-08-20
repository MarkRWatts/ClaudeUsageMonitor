import Foundation

public enum UsageWindowKind: String, Codable {
    case fiveHour
    case sevenDay

    public var duration: TimeInterval {
        switch self {
        case .fiveHour: return 5 * 60 * 60
        case .sevenDay: return 7 * 24 * 60 * 60
        }
    }

    public var label: String {
        switch self {
        case .fiveHour: return "5-Hour Session"
        case .sevenDay: return "Weekly (All Models)"
        }
    }
}

/// One poll of the usage endpoint, stored verbatim — utilization on the API's 0...100 scale,
/// spend as the original `MoneyAmount`s.
///
/// Money is the reason the spend fields aren't flattened to a percentage: limits are
/// plan-specific, so a utilization percentage means something different either side of a plan
/// change, but `spendUsed` in real currency stays comparable across one.
public struct UsageSample: Codable {
    public let recordedAt: Date
    public let epochId: String
    public let fiveHourPercent: Double?
    public let fiveHourResetsAt: Date?
    public let sevenDayPercent: Double?
    public let sevenDayResetsAt: Date?
    public let spendPercent: Double?
    public let spendUsed: MoneyAmount?
    public let spendLimit: MoneyAmount?

    public init(
        recordedAt: Date,
        epochId: String,
        fiveHourPercent: Double?,
        fiveHourResetsAt: Date?,
        sevenDayPercent: Double?,
        sevenDayResetsAt: Date?,
        spendPercent: Double?,
        spendUsed: MoneyAmount?,
        spendLimit: MoneyAmount?
    ) {
        self.recordedAt = recordedAt
        self.epochId = epochId
        self.fiveHourPercent = fiveHourPercent
        self.fiveHourResetsAt = fiveHourResetsAt
        self.sevenDayPercent = sevenDayPercent
        self.sevenDayResetsAt = sevenDayResetsAt
        self.spendPercent = spendPercent
        self.spendUsed = spendUsed
        self.spendLimit = spendLimit
    }
}

/// One completed (or still open) limit window, identified by its reset time.
///
/// `resetsAt` is the natural primary key: utilization only climbs until the reset, so the peak
/// across however many samples we caught is a sound summary of the window even when coverage
/// was patchy, and two observers of the same window merge by taking the better-informed view.
public struct UsageWindowRecord: Codable {
    public let kind: UsageWindowKind
    public let resetsAt: Date
    public var peakUtilization: Double
    public var firstSeen: Date
    public var lastSeen: Date
    public var sampleCount: Int
    public var epochId: String
    /// Set when a plan change ended this window early. The peak is still real, but it's a peak
    /// against the *old* plan's limit and can't be compared with windows either side of it.
    public var truncatedByPlanChange: Bool

    public init(
        kind: UsageWindowKind,
        resetsAt: Date,
        peakUtilization: Double,
        firstSeen: Date,
        lastSeen: Date,
        sampleCount: Int,
        epochId: String,
        truncatedByPlanChange: Bool
    ) {
        self.kind = kind
        self.resetsAt = resetsAt
        self.peakUtilization = peakUtilization
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.sampleCount = sampleCount
        self.epochId = epochId
        self.truncatedByPlanChange = truncatedByPlanChange
    }

    /// Scoped by epoch: a plan change can hand back a window whose `resets_at` matches one
    /// from the old plan, and merging those two would fuse readings taken against different
    /// limits — exactly what epochs exist to keep apart.
    ///
    /// This makes the key device-local, since epoch ids are per-device UUIDs. A future
    /// cross-device merge would resolve each epoch id to its plan capabilities via
    /// `epochs.json` first, and key on those instead.
    public var key: String {
        "\(epochId)/\(kind.rawValue)@\(Int(resetsAt.timeIntervalSince1970))"
    }

    /// Merges another view of the same window. `sampleCount` takes the max rather than the sum
    /// because the two views usually overlap — it's a coverage hint, not an exact tally.
    public func merged(with other: UsageWindowRecord) -> UsageWindowRecord {
        var result = self
        result.peakUtilization = Swift.max(peakUtilization, other.peakUtilization)
        result.firstSeen = Swift.min(firstSeen, other.firstSeen)
        result.lastSeen = Swift.max(lastSeen, other.lastSeen)
        result.sampleCount = Swift.max(sampleCount, other.sampleCount)
        result.truncatedByPlanChange = truncatedByPlanChange || other.truncatedByPlanChange
        return result
    }
}

/// A stretch of time under one set of plan capabilities.
///
/// A plan change resets every limit, so utilization either side of an epoch boundary is
/// measured against a different denominator. History must be segmented at these boundaries
/// rather than drawn as one continuous series.
public struct PlanEpoch: Codable {
    public let id: String
    public let startedAt: Date
    public var endedAt: Date?
    /// The plan-identifying capability strings (`Organization.planCapabilities`), not the
    /// mapped display name — that mapping is reverse-engineered and lossy. This is what epoch
    /// boundaries are detected on.
    public var capabilities: [String]
    /// Every capability the organization reported, kept only so a future correction to the
    /// capability mapping can be applied to history already recorded under the old one.
    public var allCapabilities: [String]
    public var planName: String?

    public init(
        id: String,
        startedAt: Date,
        endedAt: Date? = nil,
        capabilities: [String],
        allCapabilities: [String],
        planName: String?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.capabilities = capabilities
        self.allCapabilities = allCapabilities
        self.planName = planName
    }

    /// Hand-rolled so fields added as the history format grows don't strand files written by an
    /// older build.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        capabilities = try container.decodeIfPresent([String].self, forKey: .capabilities) ?? []
        allCapabilities =
            try container.decodeIfPresent([String].self, forKey: .allCapabilities) ?? []
        planName = try container.decodeIfPresent(String.self, forKey: .planName)
    }

    public var isOpen: Bool { endedAt == nil }

    /// Empty capabilities means the best-effort organization fetch hadn't succeeded yet when
    /// this epoch was opened. It's a placeholder to be filled in once one does, not a real plan
    /// boundary — treating it as one would split the history on every cold start that began
    /// with a flaky network.
    public var isProvisional: Bool { capabilities.isEmpty }
}
