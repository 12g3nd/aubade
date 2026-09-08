import SwiftUI
import AubadeCore

/// The morning edition.
///
/// One scroll that ends. There is no pagination, no infinite tail and nothing that loads
/// as you approach the bottom - reaching the games means you are finished.
public struct EditionView: View {
    private let presentation: EditionPresentation
    private let onAction: (String, ObligationAction) -> Void

    /// Items handled during this session.
    ///
    /// The pipeline drops handled work from tomorrow's edition, but removing a row the
    /// instant it is tapped loses the reader's place and leaves no way back. They stay,
    /// struck through and stamped, until the next morning rebuilds without them.
    @State private var handledThisSession: Set<String> = []
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme

    public init(
        presentation: EditionPresentation,
        onAction: @escaping (String, ObligationAction) -> Void = { _, _ in }
    ) {
        self.presentation = presentation
        self.onAction = onAction
    }

    private var edition: Edition { presentation.morning.edition }
    private var now: Date { edition.date }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Masthead(presentation: presentation)
                    .padding(.bottom, 14)

                if !presentation.stopPress.isEmpty {
                    StopPress(notices: presentation.stopPress)
                }

                if presentation.verseLeads {
                    quietMorning
                } else {
                    workingMorning
                }

                departments
            }
            .padding(.horizontal, 19)
            .padding(.bottom, 30)
        }
        .background(theme.palette.newsprint.ignoresSafeArea())
        .environment(\.theme, .forScheme(colorScheme))
    }

    // MARK: - The two front pages

    /// Nothing due, and every source answered: the verse takes the front page.
    @ViewBuilder
    private var quietMorning: some View {
        if let item = presentation.morning.cultural.item {
            FeatureVerse(item: item, allClear: presentation.allClearLine)
        } else if let line = presentation.allClearLine {
            Text(line)
                .font(theme.type.standfirst)
                .foregroundStyle(theme.palette.inkMuted)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var workingMorning: some View {
        let featured = edition.featured
        ForEach(Array(featured.enumerated()), id: \.element.id) { index, obligation in
            if index > 0 { Hairline() }
            LeadStory(obligation: obligation, now: now, secondary: index > 0)
        }

        if !edition.compact.isEmpty {
            Hairline()
            SectionHead(text: "Also this week")
            ForEach(edition.compact) { obligation in
                BriefRow(
                    obligation: obligation,
                    now: now,
                    isHandled: handledThisSession.contains(obligation.id)
                ) { action in
                    handle(action, on: obligation.id)
                }
            }
        }

        if let held = presentation.heldBackLine {
            Text(held)
                .font(theme.type.folio)
                .italic()
                .foregroundStyle(theme.palette.inkMuted)
                .padding(.top, 8)
        }

        if !edition.candidates.isEmpty {
            DoubleRule()
            SectionHead(text: "Worth checking — not confirmed", uncertain: true)
            ForEach(edition.candidates) { candidate in
                BriefRow(
                    obligation: candidate,
                    now: now,
                    isHandled: handledThisSession.contains(candidate.id)
                ) { action in
                    handle(action, on: candidate.id)
                }
            }
        }
    }

    // MARK: - Everything below the fold

    @ViewBuilder
    private var departments: some View {
        let stories = Array(presentation.morning.news.prefix(presentation.newsBudget))
        if !stories.isEmpty {
            DoubleRule()
            SectionHead(text: "The World")
            NewsSection(stories: stories)
        }

        // On a quiet morning the verse has already led, so it is not repeated here.
        if !presentation.verseLeads, let item = presentation.morning.cultural.item {
            DoubleRule()
            SectionHead(text: item.kind == .poem ? "Verse" : item.kind.rawValue.capitalized)
            VerseSection(item: item)
        }

        if let curiosity = presentation.morning.cultural.curiosity {
            Hairline()
            SectionHead(text: "Worth a detour")
            DetourSection(curiosity: curiosity)
        }

        if !presentation.morning.cultural.games.isEmpty {
            Hairline()
            SectionHead(text: "Diversions")
            GamesSection(games: presentation.morning.cultural.games)
        }

        if let footnote = presentation.countFootnote {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.palette.rule)
                .padding(.top, 14)
            Text(footnote)
                .font(theme.type.footnote)
                .foregroundStyle(theme.doubtColor)
                .padding(.top, 7)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func handle(_ action: ObligationAction, on id: String) {
        switch action {
        case .handled, .didNotNeedAction:
            handledThisSession.insert(id)
        case .snooze:
            handledThisSession.insert(id)
        }
        onAction(id, action)
    }
}
