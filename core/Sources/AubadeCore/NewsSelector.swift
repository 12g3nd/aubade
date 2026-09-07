import Foundation

/// Chooses the few stories the edition will actually carry.
///
/// The shape is fixed: one Canadian story, one major world story, and one flexible slot.
/// Keeping it fixed is the point - the edition ends, rather than becoming a feed that
/// rewards scrolling.
public struct NewsSelector: Sendable {
    /// Publishers to reach for first when a slot could be filled several ways.
    public let preferredPublishers: [String]
    /// How long a story stays eligible. Yesterday's headline is not this morning's news.
    public let maxAge: TimeInterval

    public init(
        preferredPublishers: [String] = ["AP News"],
        maxAge: TimeInterval = 36 * 3600
    ) {
        self.preferredPublishers = preferredPublishers
        self.maxAge = maxAge
    }

    /// - Parameter limit: how many slots to fill. Reduced on an overloaded morning, when
    ///   obligations matter more than the news does.
    public func select(from stories: [NewsStory], now: Date, limit: Int = 3) -> [NewsStory] {
        guard limit > 0 else { return [] }

        let fresh = stories.filter { story in
            guard let published = story.publishedAt else { return true } // undated feeds still count
            let age = now.timeIntervalSince(published)
            return age >= -3600 && age <= maxAge // tolerate slight clock skew ahead of us
        }

        var seen = Set<String>()
        let unique = fresh.filter { seen.insert($0.dedupeKey).inserted }

        var chosen: [NewsStory] = []
        var used = Set<String>()

        func take(where matches: (NewsStory) -> Bool) {
            guard chosen.count < limit else { return }
            let pool = unique.filter { !used.contains($0.id) && matches($0) }
            guard let pick = best(from: pool, avoidingPublishers: Set(chosen.map(\.publisher))) else { return }
            chosen.append(pick)
            used.insert(pick.id)
        }

        take { NewsBeat.canadianSlot.contains($0.beat) }
        take { NewsBeat.worldSlot.contains($0.beat) }
        // The flexible slot: business, science, or whatever else is left worth reading.
        take { _ in true }

        return chosen
    }

    /// Prefers a named publisher, then a publisher not already used, then recency.
    private func best(from pool: [NewsStory], avoidingPublishers used: Set<String>) -> NewsStory? {
        guard !pool.isEmpty else { return nil }
        return pool.max { a, b in rank(a, used) < rank(b, used) }
    }

    private func rank(_ story: NewsStory, _ used: Set<String>) -> (Int, Int, Date) {
        let preferred = preferredPublishers.firstIndex(where: {
            $0.caseInsensitiveCompare(story.publisher) == .orderedSame
        })
        // Higher is better in every component.
        let preferenceScore = preferred.map { preferredPublishers.count - $0 } ?? 0
        let varietyScore = used.contains(story.publisher) ? 0 : 1
        return (preferenceScore, varietyScore, story.publishedAt ?? .distantPast)
    }
}

public extension Edition {
    /// How much news an edition of this weight should carry.
    ///
    /// A morning already full of obligations gets less news, not a longer edition. One
    /// story always survives so the edition still opens onto something other than work.
    var newsBudget: Int {
        switch allObligations.count {
        case 0...3: return 3
        case 4...6: return 2
        default: return 1
        }
    }
}
