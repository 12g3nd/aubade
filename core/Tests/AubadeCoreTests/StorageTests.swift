import XCTest
@testable import AubadeCore

final class StorageTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    func day(_ offset: Int, hour: Int = 7) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 7 + offset
        components.hour = hour
        return calendar.date(from: components)!
    }

    func obligation(_ title: String, evidence: String = "from Quercus") -> Obligation {
        Obligation(
            id: "id-\(title)", title: title, source: .quercus,
            dueAt: day(0), sourceURL: URL(string: "https://q.utoronto.ca/x"),
            evidence: evidence, confidence: .stated
        )
    }

    func story(_ title: String) -> NewsStory {
        NewsStory(
            title: title, summary: "A summary.",
            url: URL(string: "https://apnews.com/\(title)")!,
            publisher: "AP News", publishedAt: day(0), beat: .world
        )
    }

    func morning(_ offset: Int, obligations: [Obligation] = [], news: [NewsStory] = []) -> MorningEdition {
        let edition = EditionBuilder().build(
            obligations: obligations,
            sources: [SourceStatus(kind: .quercus, outcome: .ok, lastSuccessAt: day(offset), checkedAt: day(offset))],
            now: day(offset)
        )
        return MorningEdition(
            edition: edition,
            news: news,
            cultural: CulturalDesk().selection(for: day(offset), calendar: calendar),
            calendar: calendar
        )
    }

    func archive(_ store: FileStore = InMemoryFileStore()) -> EditionArchive {
        EditionArchive(store: store, retentionDays: 30)
    }

    // MARK: - Round trip

    func testSavedMorningComesBackIntact() throws {
        let store = InMemoryFileStore()
        let a = archive(store)
        let original = morning(0, obligations: [obligation("Problem Set")], news: [story("Headline")])

        try a.save(original)
        let loaded = try a.morning(for: original.id)

        XCTAssertEqual(loaded, original, "a stored morning must survive encoding exactly")
    }

    func testMorningsComeBackNewestFirst() throws {
        let a = archive()
        for offset in [0, -3, -1] { try a.save(morning(offset)) }
        let dates = try a.allMornings().map(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    func testOneCorruptFileDoesNotCostTheWholeArchive() throws {
        let store = InMemoryFileStore()
        let a = archive(store)
        try a.save(morning(0))
        try store.write(Data("not json".utf8), to: "edition-2026-08-30.json")

        XCTAssertEqual(try a.allMornings().count, 1, "a damaged morning must be skipped, not fatal")
    }

    // MARK: - Retention

    func testMorningsOlderThanThirtyDaysArePruned() throws {
        let a = archive()
        try a.save(morning(0))
        try a.save(morning(-10))
        try a.save(morning(-31))
        try a.save(morning(-90))

        let removed = try a.prune(now: day(0), calendar: calendar)

        XCTAssertEqual(removed.count, 2)
        XCTAssertEqual(try a.allMornings().count, 2)
    }

    func testPruningKeepsTheBoundaryDay() throws {
        let a = archive()
        try a.save(morning(-29))
        XCTAssertTrue(try a.prune(now: day(0), calendar: calendar).isEmpty,
                      "a morning inside the window must not be removed")
    }

    func testPruningNeverTouchesSavedItemsOrMemory() throws {
        let store = InMemoryFileStore()
        let a = archive(store)
        try a.save(item: .story(story("Kept")))
        var memory = EditionMemory()
        memory.record(.handled(at: day(0)), for: "id-x")
        try a.save(memory: memory)
        try a.save(morning(-90))

        try a.prune(now: day(0), calendar: calendar)

        XCTAssertEqual(try a.savedItems().count, 1, "explicit saves outlive the window")
        XCTAssertNotNil(try a.memory().states["id-x"])
    }

    func testPruningIsSafeOnAnEmptyArchive() throws {
        XCTAssertTrue(try archive().prune(now: day(0), calendar: calendar).isEmpty)
    }

    // MARK: - Saved items

    func testSavingTheSameThingTwiceKeepsItOnce() throws {
        let a = archive()
        try a.save(item: .story(story("Same")))
        try a.save(item: .story(story("Same")))
        XCTAssertEqual(try a.savedItems().count, 1)
    }

    func testSavedItemsCanBeRemoved() throws {
        let a = archive()
        let item = SavedItem.cultural(CulturalLibrary.items[0])
        try a.save(item: item)
        try a.removeSavedItem(id: item.id)
        XCTAssertTrue(try a.savedItems().isEmpty)
    }

    // MARK: - Memory

    func testMemorySurvivesAndDefaultsToEmpty() throws {
        let a = archive()
        XCTAssertTrue(try a.memory().states.isEmpty, "a first run must not fail")

        var memory = EditionMemory()
        memory.record(.snoozed(until: day(1)), for: "id-a")
        memory.recordSuccess(.quercus, at: day(0))
        try a.save(memory: memory)

        let loaded = try a.memory()
        XCTAssertEqual(loaded.states["id-a"], .snoozed(until: day(1)))
        XCTAssertEqual(loaded.lastSuccess(for: .quercus), day(0))
    }
}

final class ExportTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    let exporter = EditionExporter()

    func day(_ offset: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 7 + offset; c.hour = 7
        return calendar.date(from: c)!
    }

    /// Distinctive strings so a leak is unmistakable rather than a judgement call.
    let secretTitle = "MEDICAL-APPOINTMENT-CONFIDENTIAL"
    let secretEvidence = "EVIDENCE-FROM-PRIVATE-EMAIL"
    let secretCandidate = "CANDIDATE-PRIVATE-THING"

    func sensitiveMorning() -> MorningEdition {
        let obligations = [
            Obligation(id: "1", title: secretTitle, source: .personalMail,
                       dueAt: day(0), evidence: secretEvidence, confidence: .stated),
            Obligation(id: "2", title: secretCandidate, source: .schoolMail,
                       dueAt: day(0), evidence: secretEvidence, confidence: .inferred)
        ]
        let failed = SourceStatus(
            kind: .schoolMail, outcome: .failed(reason: "timeout"),
            lastSuccessAt: day(-1), checkedAt: day(0)
        )
        let edition = EditionBuilder().build(obligations: obligations, sources: [failed], now: day(0))
        return MorningEdition(
            edition: edition,
            news: [NewsStory(title: "A public headline", summary: "Public summary.",
                             url: URL(string: "https://apnews.com/a")!, publisher: "AP News",
                             publishedAt: day(0), beat: .world)],
            cultural: CulturalDesk().selection(for: day(0), calendar: calendar),
            calendar: calendar
        )
    }

    // MARK: - The property that matters most

    func testPublicExportContainsNoPrivateContent() {
        let text = exporter.export(sensitiveMorning(), scope: .publicSections, calendar: calendar)

        XCTAssertFalse(text.contains(secretTitle), "an obligation title must never reach a public export")
        XCTAssertFalse(text.contains(secretEvidence), "evidence quotes private mail")
        XCTAssertFalse(text.contains(secretCandidate), "an unconfirmed guess is still private")
    }

    func testPublicExportDoesNotRevealWhichAccountsExistOrFailed() {
        let text = exporter.export(sensitiveMorning(), scope: .publicSections, calendar: calendar)
        XCTAssertFalse(text.contains("School email"), "source notices name the reader's accounts")
        XCTAssertFalse(text.contains("unavailable"))
        XCTAssertFalse(text.contains("q.utoronto.ca"))
    }

    func testPublicExportStillCarriesTheEnjoyablePart() {
        let text = exporter.export(sensitiveMorning(), scope: .publicSections, calendar: calendar)
        XCTAssertTrue(text.contains("A public headline"))
        XCTAssertTrue(text.contains("AP News"))
        XCTAssertTrue(text.contains("Games"))
        XCTAssertTrue(text.contains("Worth a detour"))
        XCTAssertTrue(text.contains("Public sections only"), "the file should say what it left out")
    }

    func testFullExportIsChosenDeliberatelyAndDoesIncludeObligations() {
        let text = exporter.export(sensitiveMorning(), scope: .fullEdition, calendar: calendar)
        XCTAssertTrue(text.contains(secretTitle))
        XCTAssertTrue(text.contains("School email unavailable"))
        XCTAssertEqual(ExportScope.allCases.first, .publicSections,
                       "the safer scope must be the one offered first")
    }

    func testExportNeverCarriesCredentials() {
        // Nothing in the model holds a token, and this asserts the shape stays that way.
        for scope in ExportScope.allCases {
            let text = exporter.export(sensitiveMorning(), scope: scope, calendar: calendar)
            for forbidden in ["Bearer", "access_token", "refresh_token", "password", "api-key"] {
                XCTAssertFalse(text.lowercased().contains(forbidden.lowercased()),
                               "\(forbidden) must never appear in an export")
            }
        }
    }

    func testExportIsSelfContainedMarkdownWithADate() {
        let text = exporter.export(sensitiveMorning(), scope: .publicSections, calendar: calendar)
        XCTAssertTrue(text.hasPrefix("# Aubade - "))
        XCTAssertTrue(text.contains("2026"))
        XCTAssertTrue(text.hasSuffix("\n"))
    }

    func testEmptyMorningExportsWithoutCrashing() {
        let edition = EditionBuilder().build(obligations: [], sources: [], now: day(0))
        let empty = MorningEdition(
            edition: edition, news: [],
            cultural: CulturalSelection(item: nil, curiosity: nil, games: []),
            calendar: calendar
        )
        for scope in ExportScope.allCases {
            XCTAssertFalse(exporter.export(empty, scope: scope, calendar: calendar).isEmpty)
        }
    }
}
