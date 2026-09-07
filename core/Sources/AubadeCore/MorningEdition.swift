import Foundation

/// One complete morning: the obligations, the news, and the enjoyable part.
///
/// `Edition` deliberately carries no raw email or assignment bodies - an `Obligation` holds
/// a title and a short line of evidence and nothing else. That is what keeps a stored
/// morning from quietly becoming an archive of your mail.
public struct MorningEdition: Codable, Sendable, Equatable, Identifiable {
    public let edition: Edition
    public let news: [NewsStory]
    public let cultural: CulturalSelection

    /// The local day this morning belongs to, as `yyyy-MM-dd`. Also its filename.
    public let id: String

    public init(edition: Edition, news: [NewsStory], cultural: CulturalSelection, calendar: Calendar = .current) {
        self.edition = edition
        self.news = news
        self.cultural = cultural
        self.id = MorningEdition.dayKey(for: edition.date, calendar: calendar)
    }

    public var date: Date { edition.date }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// Something the reader chose to keep. Saved items outlive the thirty-day window.
public enum SavedItem: Codable, Sendable, Equatable, Identifiable {
    case story(NewsStory)
    case cultural(CulturalItem)
    case curiosity(Curiosity)

    public var id: String {
        switch self {
        case .story(let s): return "story:\(s.id)"
        case .cultural(let c): return "cultural:\(c.id)"
        case .curiosity(let c): return "curiosity:\(c.id)"
        }
    }

    /// Saving is only offered for public things. There is no case here for an obligation,
    /// so a saved archive cannot accumulate coursework or mail even by mistake.
    public var isPublic: Bool { true }
}

/// What an export is allowed to contain.
public enum ExportScope: String, Codable, Sendable, CaseIterable {
    /// News, the cultural slot and the games. The default, because an exported file is
    /// the one artefact likely to leave the phone.
    case publicSections
    /// Everything, including obligations. Chosen deliberately, never by default.
    case fullEdition

    public var displayName: String {
        switch self {
        case .publicSections: return "Public sections only"
        case .fullEdition: return "Full edition"
        }
    }
}

/// Renders a morning as a self-contained Markdown file.
///
/// The public scope is a whitelist, not a filter: it builds the document from the public
/// fields rather than starting with everything and removing the private parts. A filter
/// silently leaks whatever someone forgets to add to it later.
public struct EditionExporter: Sendable {
    public init() {}

    public func export(
        _ morning: MorningEdition,
        scope: ExportScope,
        calendar: Calendar = .current
    ) -> String {
        var lines: [String] = []

        let heading = DateFormatter()
        heading.calendar = calendar
        heading.timeZone = calendar.timeZone
        heading.locale = Locale(identifier: "en_US_POSIX")
        heading.dateFormat = "EEEE, d MMMM yyyy"

        lines.append("# Aubade - \(heading.string(from: morning.date))")
        lines.append("")

        if scope == .fullEdition {
            lines += obligationSections(morning.edition)
        }

        if !morning.news.isEmpty {
            lines.append("## News")
            lines.append("")
            for story in morning.news {
                lines.append("### \(story.title)")
                if let summary = story.summary, !summary.isEmpty {
                    lines.append(summary)
                }
                lines.append("\(story.publisher) - <\(story.url.absoluteString)>")
                lines.append("")
            }
        }

        if let item = morning.cultural.item {
            lines.append("## \(item.kind.rawValue.capitalized)")
            lines.append("")
            if let title = item.title { lines.append("**\(title)**"); lines.append("") }
            lines.append(item.text)
            if let attribution = item.attribution {
                lines.append("")
                lines.append("- \(attribution)")
            }
            lines.append("")
        }

        if let curiosity = morning.cultural.curiosity {
            lines.append("## Worth a detour")
            lines.append("")
            lines.append("**\(curiosity.title)** - \(curiosity.note)")
            lines.append("<\(curiosity.url.absoluteString)>")
            lines.append("")
        }

        if !morning.cultural.games.isEmpty {
            lines.append("## Games")
            lines.append("")
            for game in morning.cultural.games {
                lines.append("- \(game.name): <\(game.url.absoluteString)>")
            }
            lines.append("")
        }

        if scope == .publicSections {
            lines.append("---")
            lines.append("Public sections only. Obligations and account status were not exported.")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private func obligationSections(_ edition: Edition) -> [String] {
        var lines: [String] = []
        lines.append("## Today")
        lines.append("")
        lines.append(edition.summaryLine)
        lines.append("")

        for notice in edition.notices {
            lines.append("> \(notice)")
        }
        if !edition.notices.isEmpty { lines.append("") }

        for item in edition.featured {
            lines.append("### \(item.title)")
            lines.append(item.evidence)
            if let due = item.dueAt {
                lines.append("Due \(ISO8601DateFormatter().string(from: due))")
            }
            if let url = item.sourceURL { lines.append("<\(url.absoluteString)>") }
            lines.append("")
        }

        if !edition.compact.isEmpty {
            lines.append("### Also")
            for item in edition.compact {
                lines.append("- \(item.title)")
            }
            lines.append("")
        }

        if !edition.candidates.isEmpty {
            lines.append("### Worth checking")
            lines.append("")
            lines.append("Not confirmed - these may already be done.")
            for item in edition.candidates {
                lines.append("- \(item.title)")
            }
            lines.append("")
        }

        return lines
    }
}
