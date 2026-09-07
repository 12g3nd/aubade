import Foundation

/// Where a piece of information came from. Every obligation keeps its origin so the
/// edition can link a judgement back to the thing that caused it.
public enum SourceKind: String, Codable, Sendable, CaseIterable {
    case quercus
    case personalMail
    case schoolMail

    public var displayName: String {
        switch self {
        case .quercus: return "Quercus"
        case .personalMail: return "Personal email"
        case .schoolMail: return "School email"
        }
    }
}

/// How much we trust that this item actually needs action.
///
/// `.stated` means the source told us directly (a Canvas assignment with a due date).
/// `.inferred` means something read the content and guessed. The two are never mixed
/// in the edition: an inferred item is always shown as a candidate, never as a fact.
public enum Confidence: String, Codable, Sendable {
    case stated
    case inferred
}

/// What the user has said about an obligation. Reading an email is not handling it,
/// so this only ever changes through an explicit action.
public enum ObligationState: Codable, Sendable, Equatable {
    case open
    case handled(at: Date)
    case snoozed(until: Date)
    case dismissed(at: Date)

    /// Whether this item should appear in the edition at `now`.
    public func isActive(at now: Date) -> Bool {
        switch self {
        case .open: return true
        case .handled, .dismissed: return false
        case .snoozed(let until): return now >= until
        }
    }
}

/// How urgent an obligation is, derived only from a real deadline.
/// Ordered so that `<` means "more urgent".
public enum Urgency: Int, Codable, Sendable, Comparable {
    case overdue = 0
    case dueSoon = 1    // within 48 hours
    case startSoon = 2  // within 14 days
    case undated = 3

    public static func < (lhs: Urgency, rhs: Urgency) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct Obligation: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let source: SourceKind
    /// A deadline taken from source data. Never inferred, never invented.
    public let dueAt: Date?
    public let sourceURL: URL?
    /// Why this is here, in the user's words rather than the model's. Shown alongside
    /// the item so a wrong judgement is visibly wrong rather than mysterious.
    public let evidence: String
    public let confidence: Confidence
    public var state: ObligationState

    public init(
        id: String,
        title: String,
        source: SourceKind,
        dueAt: Date? = nil,
        sourceURL: URL? = nil,
        evidence: String,
        confidence: Confidence,
        state: ObligationState = .open
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.dueAt = dueAt
        self.sourceURL = sourceURL
        self.evidence = evidence
        self.confidence = confidence
        self.state = state
    }

    /// Urgency at a given moment. Undated items are never promoted on a guess.
    public func urgency(at now: Date, calendar: Calendar = .current) -> Urgency {
        guard let dueAt else { return .undated }
        if dueAt < now { return .overdue }
        let interval = dueAt.timeIntervalSince(now)
        if interval <= 48 * 3600 { return .dueSoon }
        if interval <= 14 * 24 * 3600 { return .startSoon }
        return .undated
    }

    /// Near-term work must always stay visible, even on an overloaded day.
    public func mustRemainVisible(at now: Date) -> Bool {
        let u = urgency(at: now)
        return u == .overdue || u == .dueSoon
    }
}
