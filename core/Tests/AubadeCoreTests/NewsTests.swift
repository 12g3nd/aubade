import XCTest
@testable import AubadeCore

final class FeedParserTests: XCTestCase {
    let parser = FeedParser()

    func testParsesRSS2WithCDATAAndRFC822Dates() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel>
          <title>CBC</title>
          <item>
            <title><![CDATA[Ontario announces transit funding]]></title>
            <link>https://www.cbc.ca/news/story-1</link>
            <description><![CDATA[<p>The province said it would <b>expand</b> service.</p>]]></description>
            <pubDate>Mon, 07 Sep 2026 11:30:00 GMT</pubDate>
          </item>
        </channel></rss>
        """
        let stories = try parser.parse(Data(xml.utf8), defaultPublisher: "CBC", beat: .canadian)

        XCTAssertEqual(stories.count, 1)
        XCTAssertEqual(stories[0].title, "Ontario announces transit funding")
        XCTAssertEqual(stories[0].summary, "The province said it would expand service.",
                       "HTML in a feed summary must be stripped, not rendered")
        XCTAssertEqual(stories[0].publisher, "CBC")
        XCTAssertEqual(stories[0].beat, .canadian)
        XCTAssertNotNil(stories[0].publishedAt)
    }

    func testParsesAtomLinkFromAttribute() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <title>A discovery</title>
            <link rel="alternate" href="https://example.org/a"/>
            <summary>Short summary.</summary>
            <updated>2026-09-07T11:30:00Z</updated>
          </entry>
        </feed>
        """
        let stories = try parser.parse(Data(xml.utf8), defaultPublisher: "Example", beat: .science)
        XCTAssertEqual(stories.count, 1)
        XCTAssertEqual(stories[0].url.absoluteString, "https://example.org/a",
                       "Atom puts the link in an attribute, not the element text")
    }

    func testPerItemSourceOverridesTheFeedPublisher() throws {
        // This is what makes an AP slot possible: Google News names the real outlet per item.
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0"><channel>
          <item>
            <title>Something happened</title>
            <link>https://apnews.com/article/x</link>
            <source url="https://apnews.com">AP News</source>
          </item>
        </channel></rss>
        """
        let stories = try parser.parse(Data(xml.utf8), defaultPublisher: "Google News", beat: .world)
        XCTAssertEqual(stories[0].publisher, "AP News")
    }

    func testItemsWithoutUsableLinksAreSkippedNotCrashed() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0"><channel>
          <item><title>No link here</title></item>
          <item><title>Good</title><link>https://example.org/ok</link></item>
        </channel></rss>
        """
        let stories = try parser.parse(Data(xml.utf8), defaultPublisher: "X", beat: .world)
        XCTAssertEqual(stories.map(\.title), ["Good"])
    }

    func testMalformedXMLThrowsRatherThanReturningNonsense() {
        let broken = Data("<rss><channel><item><title>unclosed".utf8)
        XCTAssertThrowsError(try parser.parse(broken, defaultPublisher: "X", beat: .world))
    }

    func testEntitiesAreDecoded() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0"><channel>
          <item><title>Rock &amp; roll &#8217;26</title><link>https://example.org/e</link></item>
        </channel></rss>
        """
        let stories = try parser.parse(Data(xml.utf8), defaultPublisher: "X", beat: .world)
        XCTAssertEqual(stories[0].title, "Rock & roll \u{2019}26")
    }
}

final class NewsClientTests: XCTestCase {
    func feedXML(source: String, link: String) -> String {
        """
        <?xml version="1.0"?>
        <rss version="2.0"><channel>
          <item><title>Item</title><link>\(link)</link>
          <source url="https://x">\(source)</source></item>
        </channel></rss>
        """
    }

    func testAggregatorFeedIsFilteredToTheRequiredSource() async {
        // Google's source: operator is loose and mixes outlets, so the filter is required.
        let mixed = """
        <?xml version="1.0"?>
        <rss version="2.0"><channel>
          <item><title>AP story</title><link>https://apnews.com/a</link>
            <source url="https://apnews.com">AP News</source></item>
          <item><title>NYT story</title><link>https://nytimes.com/b</link>
            <source url="https://nytimes.com">The New York Times</source></item>
          <item><title>Local story</title><link>https://wwny.com/c</link>
            <source url="https://wwny.com">WWNY</source></item>
        </channel></rss>
        """
        let stub = StubTransport(replies: [HTTPReply(status: 200, body: Data(mixed.utf8))])
        let feed = FeedDefinition(
            url: URL(string: "https://news.google.com/rss/search?q=x")!,
            publisher: "AP News", beat: .world, requiredSource: "AP News"
        )
        let stories = await NewsClient(feeds: [feed], transport: stub).fetchStories()

        XCTAssertEqual(stories.map(\.title), ["AP story"],
                       "items from other outlets must be dropped client-side")
    }

    func testFailingFeedIsSkippedWithoutLosingTheOthers() async {
        // Keyed by URL rather than queued: feeds are fetched concurrently, so which
        // request arrives first is not defined and must not decide the outcome.
        let stub = StubTransport(byURL: [
            "https://a.example/feed": HTTPReply(status: 500, body: Data()),
            "https://b.example/feed": HTTPReply(
                status: 200,
                body: Data(feedXML(source: "CBC", link: "https://cbc.ca/a").utf8)
            )
        ])
        let feeds = [
            FeedDefinition(url: URL(string: "https://a.example/feed")!, publisher: "A", beat: .world),
            FeedDefinition(url: URL(string: "https://b.example/feed")!, publisher: "B", beat: .canadian)
        ]
        let stories = await NewsClient(feeds: feeds, transport: stub).fetchStories()
        XCTAssertEqual(stories.count, 1, "one broken feed must not empty the news")
    }

    func testConcurrentFeedsEachGetTheirOwnReply() async {
        // Guards the harness itself: an unlocked stub raced here and passed only by luck.
        let stub = StubTransport(byURL: [
            "https://one.example/feed": HTTPReply(
                status: 200, body: Data(feedXML(source: "One", link: "https://one.example/a").utf8)
            ),
            "https://two.example/feed": HTTPReply(
                status: 200, body: Data(feedXML(source: "Two", link: "https://two.example/b").utf8)
            ),
            "https://three.example/feed": HTTPReply(
                status: 200, body: Data(feedXML(source: "Three", link: "https://three.example/c").utf8)
            )
        ])
        let feeds = ["one", "two", "three"].map {
            FeedDefinition(url: URL(string: "https://\($0).example/feed")!, publisher: $0, beat: .world)
        }
        let stories = await NewsClient(feeds: feeds, transport: stub).fetchStories()
        XCTAssertEqual(Set(stories.map(\.publisher)), ["One", "Two", "Three"])
    }
}

final class NewsSelectorTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    func story(
        _ title: String,
        publisher: String = "X",
        beat: NewsBeat = .world,
        ageHours: Double = 1
    ) -> NewsStory {
        NewsStory(
            title: title,
            url: URL(string: "https://example.org/\(title.replacingOccurrences(of: " ", with: "-"))")!,
            publisher: publisher,
            publishedAt: now.addingTimeInterval(-ageHours * 3600),
            beat: beat
        )
    }

    func testFillsCanadianWorldAndFlexibleSlots() {
        let picked = NewsSelector().select(from: [
            story("world one", publisher: "Guardian", beat: .world),
            story("canada one", publisher: "CBC", beat: .canadian),
            story("science one", publisher: "Guardian", beat: .science)
        ], now: now)

        XCTAssertEqual(picked.count, 3)
        XCTAssertTrue(NewsBeat.canadianSlot.contains(picked[0].beat))
        XCTAssertTrue(NewsBeat.worldSlot.contains(picked[1].beat))
    }

    func testAPIsPreferredForTheWorldSlot() {
        let picked = NewsSelector().select(from: [
            story("guardian take", publisher: "The Guardian", beat: .world, ageHours: 0.5),
            story("ap take", publisher: "AP News", beat: .world, ageHours: 5)
        ], now: now)

        XCTAssertEqual(picked.first?.publisher, "AP News",
                       "AP wins the world slot even when another outlet filed more recently")
    }

    func testTheSameStoryFromTwoOutletsAppearsOnce() {
        // Aggregators append " - Publisher" to titles, so the dedupe key strips it.
        let picked = NewsSelector().select(from: [
            story("Fire breaks out downtown - AP News", publisher: "AP News", beat: .world),
            story("Fire breaks out downtown - CBC", publisher: "CBC", beat: .world),
            story("Budget tabled", publisher: "CBC", beat: .canadian)
        ], now: now)

        XCTAssertEqual(picked.filter { $0.title.contains("Fire breaks out") }.count, 1)
    }

    func testStaleStoriesAreDropped() {
        let picked = NewsSelector(maxAge: 12 * 3600).select(from: [
            story("old news", ageHours: 40)
        ], now: now)
        XCTAssertTrue(picked.isEmpty, "yesterday's headline is not this morning's news")
    }

    func testLimitCompressesTheNewsSection() {
        let stories = [
            story("canada", publisher: "CBC", beat: .canadian),
            story("world", publisher: "AP News", beat: .world),
            story("science", publisher: "Guardian", beat: .science)
        ]
        XCTAssertEqual(NewsSelector().select(from: stories, now: now, limit: 1).count, 1)
        XCTAssertEqual(NewsSelector().select(from: stories, now: now, limit: 0).count, 0)
    }

    func testMissingBeatDoesNotBlockRemainingSlots() {
        // No Canadian story available: the other slots must still fill.
        let picked = NewsSelector().select(from: [
            story("world", publisher: "AP News", beat: .world),
            story("science", publisher: "Guardian", beat: .science)
        ], now: now)
        XCTAssertEqual(picked.count, 2)
    }

    func testBusyMorningsGetLessNewsButNeverNone() {
        func edition(_ count: Int) -> Edition {
            let items = (0..<count).map {
                Obligation(id: "\($0)", title: "\($0)", source: .quercus,
                           dueAt: now, evidence: "e", confidence: .stated)
            }
            return EditionBuilder(featuredLimit: 3, compactLimit: 50)
                .build(obligations: items, sources: [], now: now)
        }
        XCTAssertEqual(edition(0).newsBudget, 3)
        XCTAssertEqual(edition(5).newsBudget, 2)
        XCTAssertEqual(edition(12).newsBudget, 1,
                       "a heavy morning still opens onto something other than work")
    }
}
