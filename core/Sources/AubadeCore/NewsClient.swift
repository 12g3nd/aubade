import Foundation

/// One feed the edition may draw from.
public struct FeedDefinition: Sendable, Equatable {
    public let url: URL
    public let publisher: String
    public let beat: NewsBeat
    /// Set for aggregator feeds. Google News mixes outlets regardless of the `source:`
    /// operator, so items whose `<source>` does not match are dropped client-side. This
    /// is what makes an AP slot possible without touching AP's own endpoints, which their
    /// robots.txt disallows.
    public let requiredSource: String?

    public init(url: URL, publisher: String, beat: NewsBeat, requiredSource: String? = nil) {
        self.url = url
        self.publisher = publisher
        self.beat = beat
        self.requiredSource = requiredSource
    }
}

public extension FeedDefinition {
    /// Keyless feeds only, so news needs no secrets and nothing to rotate.
    static let defaults: [FeedDefinition] = [
        FeedDefinition(
            url: URL(string: "https://news.google.com/rss/search?q=when:24h%20source:Associated%20Press&hl=en-CA&gl=CA&ceid=CA:en")!,
            publisher: "AP News",
            beat: .world,
            requiredSource: "AP News"
        ),
        FeedDefinition(
            url: URL(string: "https://www.cbc.ca/webfeed/rss/rss-topstories")!,
            publisher: "CBC",
            beat: .canadian
        ),
        FeedDefinition(
            url: URL(string: "https://www.theguardian.com/world/rss")!,
            publisher: "The Guardian",
            beat: .world
        ),
        FeedDefinition(
            url: URL(string: "https://www.theguardian.com/science/rss")!,
            publisher: "The Guardian",
            beat: .science
        ),
        FeedDefinition(
            url: URL(string: "https://thevarsity.ca/feed/")!,
            publisher: "The Varsity",
            beat: .campus
        )
    ]
}

/// Fetches and parses the news feeds.
///
/// News is public, so unlike email and coursework it is not bound by the on-device rule.
/// It is still only ever read: titles, the publisher's own summary, and a link.
public struct NewsClient: Sendable {
    private let feeds: [FeedDefinition]
    private let transport: HTTPTransport
    private let parser = FeedParser()

    public init(feeds: [FeedDefinition] = FeedDefinition.defaults, transport: HTTPTransport) {
        self.feeds = feeds
        self.transport = transport
    }

    /// Fetches every feed concurrently. A feed that fails is skipped rather than taking
    /// the rest down: unlike an obligation source, a missing headline is not something
    /// the reader needs warned about.
    public func fetchStories() async -> [NewsStory] {
        await withTaskGroup(of: [NewsStory].self) { group in
            for feed in feeds {
                group.addTask { await self.fetch(feed) }
            }
            var all: [NewsStory] = []
            for await stories in group { all += stories }
            return all
        }
    }

    private func fetch(_ feed: FeedDefinition) async -> [NewsStory] {
        do {
            let reply = try await transport.get(feed.url, headers: ["Accept": "application/rss+xml, application/xml, text/xml"])
            guard reply.status == 200 else { return [] }
            let stories = try parser.parse(
                reply.body,
                defaultPublisher: feed.publisher,
                beat: feed.beat
            )
            guard let required = feed.requiredSource else { return stories }
            return stories.filter { $0.publisher.caseInsensitiveCompare(required) == .orderedSame }
        } catch {
            return []
        }
    }
}
