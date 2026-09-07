import Foundation

/// The outcome of the last attempt to read a source.
public enum FetchOutcome: Codable, Sendable, Equatable {
    case ok
    case failed(reason: String)

    public var isOK: Bool {
        if case .ok = self { return true }
        return false
    }
}

/// What we know about one source right now.
///
/// A source that failed is not silently dropped. The edition carries its status so the
/// reader is told "School email unavailable - last checked yesterday at 8:10" rather
/// than being shown a short list and left to assume it is complete.
public struct SourceStatus: Codable, Sendable, Equatable, Identifiable {
    public let kind: SourceKind
    public let outcome: FetchOutcome
    /// The last time this source was read successfully, which may be well before now.
    public let lastSuccessAt: Date?
    public let checkedAt: Date

    public var id: String { kind.rawValue }

    public init(kind: SourceKind, outcome: FetchOutcome, lastSuccessAt: Date?, checkedAt: Date) {
        self.kind = kind
        self.outcome = outcome
        self.lastSuccessAt = lastSuccessAt
        self.checkedAt = checkedAt
    }

    public var isHealthy: Bool { outcome.isOK }

    /// A specific, honest sentence for the edition. Vague failures teach the reader to
    /// ignore the warning, so this always names the source and when it last worked.
    public func notice(relativeTo now: Date, calendar: Calendar = .current) -> String? {
        guard case .failed(let reason) = outcome else { return nil }
        guard let lastSuccessAt else {
            return "\(kind.displayName) unavailable - never synced (\(reason))"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeStyle = .short
        if calendar.isDateInToday(lastSuccessAt) {
            formatter.dateStyle = .none
            return "\(kind.displayName) unavailable - last checked today at \(formatter.string(from: lastSuccessAt))"
        }
        if calendar.isDateInYesterday(lastSuccessAt) {
            formatter.dateStyle = .none
            return "\(kind.displayName) unavailable - last checked yesterday at \(formatter.string(from: lastSuccessAt))"
        }
        formatter.dateStyle = .medium
        return "\(kind.displayName) unavailable - last checked \(formatter.string(from: lastSuccessAt))"
    }
}
