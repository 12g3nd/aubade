import Foundation

/// The beat a story belongs to, used to fill the edition's fixed slots.
public enum NewsBeat: String, Codable, Sendable, CaseIterable {
    case canadian
    case world
    case business
    case science
    case campus

    /// Beats that can satisfy the Canadian slot.
    public static let canadianSlot: Set<NewsBeat> = [.canadian, .campus]
    /// Beats that can satisfy the world slot.
    public static let worldSlot: Set<NewsBeat> = [.world]
}

/// One headline. Deliberately a pointer, not a copy: the edition carries a title, a short
/// summary the publisher itself put in the feed, and a link. Full article text is never
/// stored, which is what keeps this inside every publisher's terms.
public struct NewsStory: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    /// The publisher's own summary from the feed. Never a generated one, and never the article body.
    public let summary: String?
    public let url: URL
    public let publisher: String
    public let publishedAt: Date?
    public let beat: NewsBeat

    public init(
        title: String,
        summary: String? = nil,
        url: URL,
        publisher: String,
        publishedAt: Date? = nil,
        beat: NewsBeat
    ) {
        // The link is the identity: the same story syndicated twice is the same story.
        self.id = url.absoluteString
        self.title = title
        self.summary = summary
        self.url = url
        self.publisher = publisher
        self.publishedAt = publishedAt
        self.beat = beat
    }

    /// A loose key for spotting the same story arriving from two outlets. Punctuation and
    /// the trailing " - Publisher" that aggregators append are stripped before comparing.
    public var dedupeKey: String {
        var text = title.lowercased()
        if let separator = text.range(of: " - ", options: .backwards) {
            text = String(text[text.startIndex..<separator.lowerBound])
        }
        let kept = text.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == " "
        }
        return String(String.UnicodeScalarView(kept))
            .split(separator: " ")
            .prefix(8)
            .joined(separator: " ")
    }
}
