import Foundation

/// One morning's edition. Finite by construction: it is built once, from a fixed set of
/// inputs, and does not grow while you read it.
public struct Edition: Codable, Sendable, Equatable {
    public let date: Date
    /// The few items that get room to explain themselves.
    public let featured: [Obligation]
    /// Everything else still needing action, listed compactly.
    public let compact: [Obligation]
    /// Guesses, kept separate from facts and never counted as obligations.
    public let candidates: [Obligation]
    public let sources: [SourceStatus]
    /// Items that exist and still need action but were held back to keep the edition
    /// finite. Never includes anything overdue or due within 48 hours.
    public let deferred: [Obligation]

    public init(
        date: Date,
        featured: [Obligation],
        compact: [Obligation],
        candidates: [Obligation],
        sources: [SourceStatus],
        deferred: [Obligation] = []
    ) {
        self.date = date
        self.featured = featured
        self.compact = compact
        self.candidates = candidates
        self.sources = sources
        self.deferred = deferred
    }

    /// Every obligation the edition is asserting, in reading order.
    public var allObligations: [Obligation] { featured + compact }

    public var failedSources: [SourceStatus] { sources.filter { !$0.isHealthy } }

    public var notices: [String] {
        failedSources.compactMap { $0.notice(relativeTo: date) }
    }

    /// Whether the edition is entitled to tell the reader they are caught up.
    ///
    /// This is the load-bearing rule of the whole app. An empty list means "we found
    /// nothing", which is only the same as "there is nothing" when every source
    /// actually answered. If any source failed, the edition must stay silent about
    /// completeness rather than reassure the reader falsely.
    public var canClaimComplete: Bool {
        allObligations.isEmpty && candidates.isEmpty && deferred.isEmpty && failedSources.isEmpty
    }

    /// The honest headline for the top of the edition.
    public var summaryLine: String {
        if canClaimComplete { return "Nothing needs you this morning." }
        let count = allObligations.count
        if count == 0 && !failedSources.isEmpty {
            return "Nothing found in the sources that answered."
        }
        return count == 1 ? "1 thing needs you today." : "\(count) things need you today."
    }
}
