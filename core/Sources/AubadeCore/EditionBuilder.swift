import Foundation

/// Turns whatever the sources returned into one finite edition.
///
/// The builder makes no network calls and reads no clock of its own: both are passed in,
/// so an edition is a pure function of its inputs and can be tested exactly.
public struct EditionBuilder: Sendable {
    /// How many items get room to explain themselves.
    public let featuredLimit: Int
    /// How many *non-urgent* items may appear in the compact list. Urgent work is never
    /// counted against this budget.
    public let compactLimit: Int

    public init(featuredLimit: Int = 3, compactLimit: Int = 7) {
        self.featuredLimit = featuredLimit
        self.compactLimit = compactLimit
    }

    public func build(
        obligations: [Obligation],
        sources: [SourceStatus],
        now: Date
    ) -> Edition {
        let active = obligations.filter { $0.state.isActive(at: now) }

        // Guesses never sit in the same list as facts.
        let stated = active.filter { $0.confidence == .stated }
        let inferred = active.filter { $0.confidence == .inferred }

        let ranked = stated.sorted { lhs, rhs in
            let lu = lhs.urgency(at: now), ru = rhs.urgency(at: now)
            if lu != ru { return lu < ru }
            switch (lhs.dueAt, rhs.dueAt) {
            case let (l?, r?) where l != r: return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            default: return lhs.title < rhs.title
            }
        }

        let featured = Array(ranked.prefix(featuredLimit))
        let remainder = Array(ranked.dropFirst(featuredLimit))

        // Anything overdue or due inside 48 hours is shown no matter how full the day is.
        // Only genuinely non-urgent work can be deferred.
        var compact: [Obligation] = []
        var deferred: [Obligation] = []
        var budget = compactLimit
        for item in remainder {
            if item.mustRemainVisible(at: now) {
                compact.append(item)
            } else if budget > 0 {
                compact.append(item)
                budget -= 1
            } else {
                deferred.append(item)
            }
        }

        return Edition(
            date: now,
            featured: featured,
            compact: compact,
            candidates: inferred.sorted { $0.title < $1.title },
            sources: sources,
            deferred: deferred
        )
    }
}
