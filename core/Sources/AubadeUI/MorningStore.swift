import Foundation
import SwiftUI
import AubadeCore

/// Holds the morning and the work of preparing it.
///
/// The edition is built when the app opens rather than in the background, so the first
/// thing on screen is whatever was stored last - readable immediately and plainly dated -
/// while today's is assembled behind it. Nothing here blocks on the network.
@MainActor
public final class MorningStore: ObservableObject {
    public enum State {
        /// Building today's edition. Carries the last stored morning so there is something
        /// to read meanwhile, and its date so it cannot be mistaken for today's.
        case preparing(previous: EditionPresentation?)
        case ready(EditionPresentation)
        /// No account is connected, so there is nothing to check yet.
        case needsSetup
    }

    @Published public private(set) var state: State = .preparing(previous: nil)
    @Published public private(set) var missingFonts: [String] = []

    private let archive: EditionArchive
    private let credentials: CredentialStore
    private let transport: HTTPTransport
    private let calendar: Calendar
    private let firstEdition: Date
    private let clock: @Sendable () -> Date

    public init(
        archive: EditionArchive,
        credentials: CredentialStore,
        transport: HTTPTransport = URLSessionTransport(),
        calendar: Calendar = .current,
        firstEdition: Date? = nil,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.archive = archive
        self.credentials = credentials
        self.transport = transport
        self.calendar = calendar
        self.clock = clock
        // Before the first morning is stored, today is the first edition.
        self.firstEdition = firstEdition ?? clock()
    }

    // MARK: - Opening the app

    public func open() async {
        AubadeFonts.register()
        missingFonts = AubadeFonts.missing()

        showLastStoredMorning()
        await prepareTodaysEdition()
    }

    /// Puts something readable on screen before any network call is made.
    private func showLastStoredMorning() {
        let today = MorningEdition.dayKey(for: clock(), calendar: calendar)
        guard let stored = (try? archive.allMornings())?.first else { return }

        let presentation = present(stored)
        // A stored edition from today is today's edition; anything older is shown as the
        // previous one until the refresh lands.
        state = stored.id == today ? .ready(presentation) : .preparing(previous: presentation)
    }

    private func prepareTodaysEdition() async {
        let now = clock()
        let sources = configuredSources()

        guard !sources.isEmpty else {
            if case .ready = state {} else { state = .needsSetup }
            return
        }

        let memory = (try? archive.memory()) ?? EditionMemory()
        let result = await EditionPipeline(sources: sources).assemble(now: now, memory: memory)

        let news = await NewsClient(transport: transport).fetchStories()
        let chosen = NewsSelector().select(
            from: news, now: now, limit: result.edition.newsBudget
        )

        let morning = MorningEdition(
            edition: result.edition,
            news: chosen,
            cultural: CulturalDesk().selection(for: now, calendar: calendar),
            calendar: calendar
        )

        try? archive.save(morning)
        try? archive.save(memory: result.memory)
        // Housekeeping happens after the reader already has their edition, never before it.
        try? archive.prune(now: now, calendar: calendar)

        state = .ready(present(morning))
    }

    private func configuredSources() -> [any ObligationSource] {
        var sources: [any ObligationSource] = []
        if let token = try? credentials.token(for: .quercus), !token.isEmpty {
            sources.append(QuercusClient(token: token, transport: transport))
        }
        return sources
    }

    private func present(_ morning: MorningEdition) -> EditionPresentation {
        EditionPresentation(morning: morning, firstEdition: firstEdition, calendar: calendar)
    }

    // MARK: - What the reader decides

    /// Records a decision immediately, so it survives even if the app is closed before the
    /// next refresh. The row stays on screen until tomorrow rebuilds without it.
    public func record(_ action: ObligationAction, for id: String) {
        var memory = (try? archive.memory()) ?? EditionMemory()
        let now = clock()
        switch action {
        case .handled:
            memory.record(.handled(at: now), for: id)
        case .didNotNeedAction:
            memory.record(.dismissed(at: now), for: id)
        case .snooze:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            memory.record(.snoozed(until: tomorrow), for: id)
        }
        try? archive.save(memory: memory)
    }

    public func saveQuercusToken(_ token: String) async {
        try? credentials.setToken(token, for: .quercus)
        state = .preparing(previous: currentPresentation)
        await prepareTodaysEdition()
    }

    public var hasQuercusToken: Bool {
        ((try? credentials.token(for: .quercus)) ?? nil)?.isEmpty == false
    }

    private var currentPresentation: EditionPresentation? {
        switch state {
        case .ready(let p): return p
        case .preparing(let p): return p
        case .needsSetup: return nil
        }
    }
}
