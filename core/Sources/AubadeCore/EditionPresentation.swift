import Foundation

/// The decisions the front page makes about itself, kept out of the views so they can be
/// tested without rendering anything.
///
/// The important one is `countIsUncertain`. The folio line carries a count, and a count is
/// the most glanceable thing on the screen - so when a source did not answer, the number
/// itself has to carry the doubt rather than relying on the reader scrolling to a notice.
public struct EditionPresentation: Sendable {
    public let morning: MorningEdition
    private let calendar: Calendar
    /// Editions are numbered from the day the app was first opened, the way a paper
    /// numbers issues from its first printing.
    private let firstEdition: Date

    public init(
        morning: MorningEdition,
        firstEdition: Date,
        calendar: Calendar = .current
    ) {
        self.morning = morning
        self.firstEdition = firstEdition
        self.calendar = calendar
    }

    private var edition: Edition { morning.edition }

    // MARK: - What kind of morning this is

    /// On a morning with nothing to do, the verse runs as the front-page feature.
    ///
    /// Gated on `canClaimComplete` rather than on an empty list: if a source failed, the
    /// day only *looks* clear, and leading with a poem would be a quiet lie.
    public var verseLeads: Bool { edition.canClaimComplete }

    /// True when at least one source did not answer, so nothing counted here is complete.
    public var countIsUncertain: Bool { !edition.failedSources.isEmpty }

    public var overdueCount: Int {
        edition.allObligations.filter { $0.urgency(at: edition.date) == .overdue }.count
    }

    public var dueCount: Int { edition.allObligations.count - overdueCount }

    // MARK: - The folio line

    /// The count as it appears in the folio, with its asterisk when it cannot be trusted.
    public var countLabel: String {
        let base: String
        if edition.canClaimComplete {
            base = "Nothing due"
        } else if edition.allObligations.isEmpty {
            base = "Nothing found"
        } else if overdueCount > 0 && dueCount > 0 {
            base = "\(overdueCount) late · \(dueCount) due"
        } else if overdueCount > 0 {
            base = overdueCount == 1 ? "1 late" : "\(overdueCount) late"
        } else {
            base = "\(dueCount) due"
        }
        return countIsUncertain ? base + "*" : base
    }

    /// The footnote the asterisk points at. Nil when the count is trustworthy.
    public var countFootnote: String? {
        guard countIsUncertain else { return nil }
        let n = edition.failedSources.count
        let sources = n == 1 ? "One source" : "\(n) sources"
        return "* The count is incomplete. \(sources) did not answer this morning."
    }

    public var folioDate: String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE d MMM"
        return f.string(from: edition.date)
    }

    /// Issue numbers start at 1 on the first morning, and never go below it.
    public var issueNumber: Int {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: firstEdition),
            to: calendar.startOfDay(for: edition.date)
        ).day ?? 0
        return max(1, days + 1)
    }

    public var folioIssue: String { "No. \(issueNumber)" }

    // MARK: - Sections

    /// The all-clear line, shown only on a morning entitled to one.
    public var allClearLine: String? {
        guard edition.canClaimComplete else { return nil }
        let named = edition.sources.map { $0.kind.displayName.lowercased() }.sorted()
        guard !named.isEmpty else { return "Nothing needs you this morning." }
        return "\(named.joined(separator: ", ").sentenceCased) all answered."
    }

    /// Notices for every source that failed, each naming the source and when it last worked.
    public var stopPress: [String] { edition.notices }

    /// How much news this morning carries, reduced on a heavy day but never to nothing.
    public var newsBudget: Int { edition.newsBudget }

    public var heldBackLine: String? {
        let n = edition.deferred.count
        guard n > 0 else { return nil }
        return n == 1
            ? "One further item held back until next week."
            : "\(n) further items held back until next week."
    }
}

private extension String {
    var sentenceCased: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
