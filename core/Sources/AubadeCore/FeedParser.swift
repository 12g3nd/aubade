import Foundation

/// Parses RSS 2.0 and Atom into stories.
///
/// Written against the shapes the chosen feeds actually emit rather than the specs in
/// full: CBC and the Globe are RSS 2.0, The Varsity is WordPress RSS, and Google News is
/// RSS 2.0 carrying a per-item `<source>` naming the originating outlet, which is what
/// makes filtering to AP possible.
public struct FeedParser {
    public init() {}

    public func parse(
        _ data: Data,
        defaultPublisher: String,
        beat: NewsBeat
    ) throws -> [NewsStory] {
        let delegate = FeedParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw SourceError.malformedResponse(
                parser.parserError?.localizedDescription ?? "unparsable feed"
            )
        }
        return delegate.entries.compactMap { entry in
            guard let title = entry.title?.cleanedFeedText, !title.isEmpty,
                  let link = entry.link?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: link)
            else { return nil }
            return NewsStory(
                title: title,
                summary: entry.summary?.cleanedFeedText,
                url: url,
                publisher: entry.source?.cleanedFeedText ?? defaultPublisher,
                publishedAt: entry.date.flatMap(FeedDate.parse),
                beat: beat
            )
        }
    }
}

// MARK: - Parsing

struct FeedEntry {
    var title: String?
    var link: String?
    var summary: String?
    var date: String?
    /// Present on aggregator feeds; names the outlet the item actually came from.
    var source: String?
}

private final class FeedParserDelegate: NSObject, XMLParserDelegate {
    var entries: [FeedEntry] = []

    private var current: FeedEntry?
    private var buffer = ""
    private var path: [String] = []

    private static let itemElements: Set<String> = ["item", "entry"]

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String]
    ) {
        let name = elementName.lowercased()
        path.append(name)
        buffer = ""

        if Self.itemElements.contains(name) {
            current = FeedEntry()
            return
        }
        guard current != nil else { return }

        // Atom puts the link in an attribute rather than the element's text, and uses rel
        // to distinguish the article from related resources.
        if name == "link", let href = attributes["href"] {
            let rel = attributes["rel"] ?? "alternate"
            if rel == "alternate", current?.link == nil { current?.link = href }
        }
        // Google News: <source url="https://apnews.com">AP News</source>
        if name == "source" { buffer = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let text = String(data: CDATABlock, encoding: .utf8) { buffer += text }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.lowercased()
        defer {
            if !path.isEmpty { path.removeLast() }
            buffer = ""
        }

        if Self.itemElements.contains(name) {
            if let entry = current { entries.append(entry) }
            current = nil
            return
        }
        guard current != nil else { return }

        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        switch name {
        case "title":
            if current?.title == nil { current?.title = text }
        case "link":
            if current?.link == nil { current?.link = text }
        case "description", "summary", "content":
            if current?.summary == nil { current?.summary = text }
        case "pubdate", "published", "updated":
            if current?.date == nil { current?.date = text }
        case "source":
            if current?.source == nil { current?.source = text }
        default:
            break
        }
    }
}

// MARK: - Dates

enum FeedDate {
    /// RSS carries RFC 822 dates, Atom carries ISO 8601, and real feeds mix both.
    static func parse(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) { return date }

        for format in rfc822Formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    private static let rfc822Formats = [
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm zzz"
    ]
}

extension String {
    /// Feed text routinely carries HTML and entities. The edition shows plain text, so
    /// tags are stripped rather than rendered.
    var cleanedFeedText: String {
        var text = self
        while let open = text.firstIndex(of: "<"),
              let close = text[open...].firstIndex(of: ">") {
            text.removeSubrange(open...close)
        }
        let entities = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&apos;": "'", "&nbsp;": " ", "&#8217;": "\u{2019}",
            "&#8216;": "\u{2018}", "&#8220;": "\u{201C}", "&#8221;": "\u{201D}"
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
