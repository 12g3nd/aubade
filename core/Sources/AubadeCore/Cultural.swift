import Foundation

public enum CulturalKind: String, Codable, Sendable, CaseIterable {
    case poem
    case quote
    case fact
}

/// The enjoyable half of the edition: one small thing worth reading that is not work.
public struct CulturalItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let kind: CulturalKind
    public let title: String?
    public let text: String
    public let attribution: String?

    public init(
        id: String,
        kind: CulturalKind,
        title: String? = nil,
        text: String,
        attribution: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.text = text
        self.attribution = attribution
    }
}

/// A website worth a detour. Curated rather than randomised: the point is that it is
/// good, not that it is arbitrary.
public struct Curiosity: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let url: URL
    public let note: String

    public init(id: String, title: String, url: URL, note: String) {
        self.id = id
        self.title = title
        self.url = url
        self.note = note
    }
}

public struct GameLink: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let url: URL

    public init(id: String, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }
}

/// What the cultural half of one morning contains.
public struct CulturalSelection: Codable, Sendable, Equatable {
    public let item: CulturalItem?
    public let curiosity: Curiosity?
    public let games: [GameLink]

    public init(item: CulturalItem?, curiosity: Curiosity?, games: [GameLink]) {
        self.item = item
        self.curiosity = curiosity
        self.games = games
    }
}

/// Chooses the cultural slot for a given morning.
///
/// Deliberately offline and deterministic. Offline because the edition has to open on a
/// subway with no signal, and because a poetry API being down should not cost you the one
/// part of the morning that is not an obligation. Deterministic because the edition is
/// prepared when you open the app: reopening it an hour later must show the same morning,
/// not reroll it.
public struct CulturalDesk: Sendable {
    private let items: [CulturalItem]
    private let curiosities: [Curiosity]
    private let games: [GameLink]

    /// The slot leads with poetry and rotates the shorter forms through it, so most
    /// mornings carry a poem without every morning being the same shape.
    private static let kindCycle: [CulturalKind] = [.poem, .quote, .poem, .fact]

    public init(
        items: [CulturalItem] = CulturalLibrary.items,
        curiosities: [Curiosity] = CulturalLibrary.curiosities,
        games: [GameLink] = CulturalLibrary.games
    ) {
        self.items = items
        self.curiosities = curiosities
        self.games = games
    }

    public func selection(for date: Date, calendar: Calendar = .current) -> CulturalSelection {
        let day = Self.dayNumber(for: date, calendar: calendar)

        let kind = Self.kindCycle[day % Self.kindCycle.count]
        // Fall back to whatever exists if a pool is empty, so a thin library still yields
        // something rather than an empty slot.
        let pool = items.filter { $0.kind == kind }
        let chosen = pool.isEmpty ? items : pool

        return CulturalSelection(
            item: chosen.isEmpty ? nil : chosen[(day / Self.kindCycle.count) % chosen.count],
            curiosity: curiosities.isEmpty ? nil : curiosities[day % curiosities.count],
            games: games
        )
    }

    /// Whole days since a fixed reference, so the selection turns over at local midnight
    /// rather than at an arbitrary hour.
    static func dayNumber(for date: Date, calendar: Calendar) -> Int {
        let reference = Date(timeIntervalSince1970: 0)
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: reference),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        // Guard against dates before the reference producing a negative index.
        return days >= 0 ? days : -days
    }
}
