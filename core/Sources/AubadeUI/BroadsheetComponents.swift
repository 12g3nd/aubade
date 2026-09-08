import SwiftUI
import AubadeCore

// MARK: - Rules

/// The double rule a paper uses between departments.
struct DoubleRule: View {
    @Environment(\.theme) private var theme
    var body: some View {
        VStack(spacing: 1.5) {
            Rectangle().frame(height: 1)
            Rectangle().frame(height: 1)
        }
        .foregroundStyle(theme.palette.ink)
        .padding(.vertical, 12)
        .accessibilityHidden(true)
    }
}

struct Hairline: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundStyle(theme.palette.rule)
            .padding(.vertical, 10)
            .accessibilityHidden(true)
    }
}

/// Letter-spaced caps naming a department.
struct SectionHead: View {
    let text: String
    var uncertain = false
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text.uppercased())
            .font(theme.type.sectionHead)
            .tracking(1.7)
            .foregroundStyle(uncertain ? theme.doubtColor : theme.palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 7)
    }
}

// MARK: - Masthead

struct Masthead: View {
    let presentation: EditionPresentation
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text("Aubade")
                .font(theme.type.masthead)
                .textCase(.lowercase)
                .foregroundStyle(theme.palette.ink)
                .padding(.vertical, 7)
                .accessibilityAddTraits(.isHeader)

            Rectangle().frame(height: 2.5).foregroundStyle(theme.palette.ink)

            HStack(alignment: .firstTextBaseline) {
                folioText(presentation.folioDate, emphasis: false)
                Spacer(minLength: 6)
                // The count sits where a paper puts its edition metadata, and carries its
                // own asterisk when a source did not answer.
                folioText(presentation.countLabel, emphasis: true)
                    .foregroundStyle(countColor)
                Spacer(minLength: 6)
                folioText(presentation.folioIssue, emphasis: false)
            }
            .padding(.vertical, 5)

            Rectangle().frame(height: 1).foregroundStyle(theme.palette.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var countColor: Color {
        if presentation.countIsUncertain { return theme.doubtColor }
        if presentation.overdueCount > 0 { return theme.doubtColor }
        return presentation.verseLeads ? theme.palette.inkMuted : theme.palette.ink
    }

    private func folioText(_ text: String, emphasis: Bool) -> some View {
        Text(text.uppercased())
            .font(emphasis ? theme.type.folioEmphasis : theme.type.folio)
            .tracking(0.9)
            .foregroundStyle(theme.palette.inkMuted)
    }

    private var accessibilityLabel: String {
        var parts = ["Aubade", presentation.folioDate, presentation.countLabel]
        if presentation.countIsUncertain {
            parts.append("This count is incomplete because a source did not answer.")
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Stop press

/// A source that failed, in the position a paper reserves for late news.
struct StopPress: View {
    let notices: [String]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("STOP PRESS")
                .font(theme.type.stamp)
                .tracking(1.5)
                .foregroundStyle(theme.doubtColor)
            ForEach(notices, id: \.self) { notice in
                Text(notice)
                    .font(theme.type.standfirst)
                    .foregroundStyle(theme.palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.palette.rule.opacity(0.35))
        .overlay(alignment: .leading) {
            Rectangle().frame(width: 4).foregroundStyle(theme.doubtColor)
        }
        .overlay {
            Rectangle().stroke(theme.doubtColor, lineWidth: 1)
        }
        .padding(.bottom, 14)
    }
}

// MARK: - Lead story

/// The most urgent obligation, given room to explain itself.
struct LeadStory: View {
    let obligation: Obligation
    let now: Date
    var secondary = false
    @Environment(\.theme) private var theme

    private var urgency: Urgency { obligation.urgency(at: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(kicker.uppercased())
                .font(theme.type.kicker)
                .tracking(1.4)
                .foregroundStyle(theme.color(for: urgency))

            Text(obligation.title)
                .font(secondary ? theme.type.leadSecondary : theme.type.lead)
                .foregroundStyle(theme.palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(obligation.evidence)
                .font(theme.type.standfirst)
                .foregroundStyle(theme.palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let due = obligation.dueAt {
                Text(Self.dueLine(due, now: now))
                    .font(theme.type.meta)
                    .foregroundStyle(theme.palette.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var kicker: String {
        switch urgency {
        case .overdue: return "Overdue · \(courseOrSource)"
        case .dueSoon: return "Due soon · \(courseOrSource)"
        case .startSoon, .undated: return courseOrSource
        }
    }

    private var courseOrSource: String { obligation.source.displayName }

    static func dueLine(_ due: Date, now: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE d MMM, h:mm a"
        return due < now ? "Was due \(f.string(from: due))" : "Due \(f.string(from: due))"
    }
}

// MARK: - Briefs

enum ObligationAction { case handled, snooze, didNotNeedAction }

/// One line in the brief list.
///
/// Actions hang off a context menu rather than a swipe. `.swipeActions` only exists inside
/// `List`, which brings its own background and separators and fights the newsprint ground -
/// and a hand-rolled drag gesture is not something to ship untested on a device we cannot
/// yet install to. Revisit once the app runs on the phone.
struct BriefRow: View {
    let obligation: Obligation
    let now: Date
    let isHandled: Bool
    let action: (ObligationAction) -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(whenLabel.uppercased())
                .font(theme.type.folio)
                .foregroundStyle(isHandled ? theme.handledColor : theme.color(for: obligation.urgency(at: now)))
                .frame(minWidth: 38, alignment: .leading)

            Text(obligation.title)
                .font(theme.type.briefEmphasis)
                .strikethrough(isHandled, pattern: .solid)
                .foregroundStyle(isHandled ? theme.handledColor : theme.palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if isHandled {
                Text("HANDLED")
                    .font(theme.type.stamp)
                    .tracking(1.2)
                    .foregroundStyle(theme.handledColor)
                    .padding(.horizontal, 3)
                    .overlay { Rectangle().stroke(theme.handledColor, lineWidth: 1) }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
        .contextMenu {
            Button("Handled") { action(.handled) }
            Button("Snooze until tomorrow") { action(.snooze) }
            Button("Didn't need action") { action(.didNotNeedAction) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(obligation.title). \(whenLabel).\(isHandled ? " Handled." : "")")
    }

    private var whenLabel: String {
        guard let due = obligation.dueAt else { return "?" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE d"
        return f.string(from: due)
    }
}

// MARK: - News

struct NewsSection: View {
    let stories: [NewsStory]
    @Environment(\.theme) private var theme

    private let columns = [
        GridItem(.flexible(), spacing: 14, alignment: .topLeading),
        GridItem(.flexible(), spacing: 14, alignment: .topLeading)
    ]

    var body: some View {
        // A single story gets the full measure; two or more set in columns, the way a
        // paper would rather than leaving a lone column stranded beside white space.
        if stories.count == 1, let story = stories.first {
            StoryCell(story: story)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(stories) { story in
                    StoryCell(story: story)
                }
            }
        }
    }
}

struct StoryCell: View {
    let story: NewsStory
    @Environment(\.theme) private var theme

    var body: some View {
        Link(destination: story.url) {
            VStack(alignment: .leading, spacing: 3) {
                Text(story.publisher.uppercased())
                    .font(theme.type.kicker)
                    .tracking(1.3)
                    .foregroundStyle(theme.palette.spot)
                Text(story.title)
                    .font(theme.type.storyTitle)
                    .foregroundStyle(theme.palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary = story.summary, !summary.isEmpty {
                    Text(summary)
                        .font(theme.type.storyBody)
                        .foregroundStyle(theme.palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(story.title). From \(story.publisher).")
    }
}

// MARK: - Verse

struct VerseSection: View {
    let item: CulturalItem
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 7) {
            Text(item.text)
                .font(theme.type.verse)
                .foregroundStyle(theme.palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let attribution = item.attribution {
                Text(attribution.uppercased())
                    .font(theme.type.folio)
                    .tracking(1.3)
                    .foregroundStyle(theme.palette.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The quiet morning's front page: the verse runs as the lead feature, at full length.
struct FeatureVerse: View {
    let item: CulturalItem
    let allClear: String?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            if let allClear {
                Text(allClear)
                    .font(theme.type.standfirst)
                    .italic()
                    .foregroundStyle(theme.palette.inkMuted)
                    .multilineTextAlignment(.center)
            }
            if let title = item.title {
                Text(title)
                    .font(theme.type.featureTitle)
                    .foregroundStyle(theme.palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(item.text)
                .font(theme.type.featureVerse)
                .foregroundStyle(theme.palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let attribution = item.attribution {
                Text(attribution.uppercased())
                    .font(theme.type.folio)
                    .tracking(1.4)
                    .foregroundStyle(theme.palette.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

// MARK: - Detour and games

struct DetourSection: View {
    let curiosity: Curiosity
    @Environment(\.theme) private var theme

    var body: some View {
        Link(destination: curiosity.url) {
            (Text(curiosity.title).font(theme.type.briefEmphasis)
             + Text(" — \(curiosity.note)").font(theme.type.brief))
                .foregroundStyle(theme.palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

struct GamesSection: View {
    let games: [GameLink]
    @Environment(\.theme) private var theme

    var body: some View {
        // Wraps rather than scrolls: the games are a short fixed set, and a row that
        // scrolls sideways hides its own contents.
        FlowLayout(spacing: 4) {
            ForEach(games) { game in
                Link(destination: game.url) {
                    Text(game.name)
                        .font(theme.type.folio)
                        .foregroundStyle(theme.palette.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .overlay { Rectangle().stroke(theme.palette.ink, lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A minimal wrapping row. `LazyVGrid` cannot size columns to their content, and a fixed
/// column count strands short labels beside long ones.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
