import XCTest
@testable import AubadeCore

final class EditionPresentationTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    func day(_ offset: Int, hour: Int = 7) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 7 + offset; c.hour = hour
        return calendar.date(from: c)!
    }

    func obligation(_ id: String, due: TimeInterval?, confidence: Confidence = .stated) -> Obligation {
        Obligation(
            id: id, title: id, source: .quercus,
            dueAt: due.map { day(0).addingTimeInterval($0) },
            evidence: "e", confidence: confidence
        )
    }

    func present(
        obligations: [Obligation] = [],
        sources: [SourceStatus] = [SourceStatus(kind: .quercus, outcome: .ok, lastSuccessAt: nil, checkedAt: Date())],
        cultural: CulturalSelection? = nil,
        firstEditionOffset: Int = 0
    ) -> EditionPresentation {
        let edition = EditionBuilder().build(obligations: obligations, sources: sources, now: day(0))
        let morning = MorningEdition(
            edition: edition,
            news: [],
            cultural: cultural ?? CulturalDesk().selection(for: day(0), calendar: calendar),
            calendar: calendar
        )
        return EditionPresentation(
            morning: morning,
            firstEdition: day(firstEditionOffset),
            calendar: calendar
        )
    }

    var failedMail: SourceStatus {
        SourceStatus(kind: .schoolMail, outcome: .failed(reason: "timeout"),
                     lastSuccessAt: day(-1), checkedAt: day(0))
    }

    var okQuercus: SourceStatus {
        SourceStatus(kind: .quercus, outcome: .ok, lastSuccessAt: day(0), checkedAt: day(0))
    }

    // MARK: - The count carries its own doubt

    func testCountIsAsteriskedWhenASourceDidNotAnswer() {
        let p = present(
            obligations: [obligation("a", due: 3600), obligation("b", due: 7200)],
            sources: [okQuercus, failedMail]
        )
        XCTAssertEqual(p.countLabel, "2 due*")
        XCTAssertTrue(p.countIsUncertain)
        XCTAssertNotNil(p.countFootnote)
        XCTAssertTrue(p.countFootnote!.contains("One source"))
    }

    func testCountHasNoAsteriskWhenEverySourceAnswered() {
        let p = present(obligations: [obligation("a", due: 3600)], sources: [okQuercus])
        XCTAssertEqual(p.countLabel, "1 due")
        XCTAssertFalse(p.countIsUncertain)
        XCTAssertNil(p.countFootnote)
    }

    func testFootnoteCountsEveryFailedSource() {
        let alsoFailed = SourceStatus(kind: .personalMail, outcome: .failed(reason: "offline"),
                                      lastSuccessAt: nil, checkedAt: day(0))
        let p = present(sources: [failedMail, alsoFailed])
        XCTAssertTrue(p.countFootnote!.contains("2 sources"))
    }

    func testOverdueWorkIsCountedSeparatelyFromUpcoming() {
        let p = present(
            obligations: [
                obligation("late", due: -86_400),
                obligation("soon", due: 3600),
                obligation("also", due: 7200)
            ],
            sources: [okQuercus]
        )
        XCTAssertEqual(p.countLabel, "1 late · 2 due")
        XCTAssertEqual(p.overdueCount, 1)
        XCTAssertEqual(p.dueCount, 2)
    }

    func testOnlyOverdueWorkReadsAsLate() {
        let p = present(obligations: [obligation("late", due: -3600)], sources: [okQuercus])
        XCTAssertEqual(p.countLabel, "1 late")
    }

    func testNothingDueReadsAsNothingDue() {
        XCTAssertEqual(present(sources: [okQuercus]).countLabel, "Nothing due")
    }

    /// The distinction the whole app turns on: an empty list with a broken source is
    /// "nothing found", never "nothing due".
    func testEmptyWithAFailedSourceNeverReadsAsNothingDue() {
        let p = present(sources: [okQuercus, failedMail])
        XCTAssertEqual(p.countLabel, "Nothing found*")
        XCTAssertNotEqual(p.countLabel, "Nothing due")
    }

    // MARK: - Which front page

    func testVerseLeadsOnlyWhenTheDayIsGenuinelyClear() {
        XCTAssertTrue(present(sources: [okQuercus]).verseLeads)
        XCTAssertFalse(present(sources: [okQuercus, failedMail]).verseLeads,
                       "a poem must not lead a morning we cannot vouch for")
        XCTAssertFalse(present(obligations: [obligation("a", due: 3600)], sources: [okQuercus]).verseLeads)
    }

    func testAllClearLineNamesTheSourcesThatAnswered() {
        let p = present(sources: [okQuercus, SourceStatus(kind: .personalMail, outcome: .ok, lastSuccessAt: day(0), checkedAt: day(0))])
        let line = p.allClearLine!
        XCTAssertTrue(line.contains("quercus"))
        XCTAssertTrue(line.contains("personal email"))
        XCTAssertTrue(line.hasSuffix("all answered."))
        XCTAssertEqual(line.first, "P", "the line should read as a sentence")
    }

    func testNoAllClearLineWhenTheDayIsNotClear() {
        XCTAssertNil(present(sources: [okQuercus, failedMail]).allClearLine)
        XCTAssertNil(present(obligations: [obligation("a", due: 3600)], sources: [okQuercus]).allClearLine)
    }

    // MARK: - Folio

    func testIssueNumbersStartAtOneAndAdvanceDaily() {
        XCTAssertEqual(present(firstEditionOffset: 0).issueNumber, 1)
        XCTAssertEqual(present(firstEditionOffset: -13).issueNumber, 14)
        XCTAssertEqual(present(firstEditionOffset: 5).issueNumber, 1,
                       "an edition dated before the first must not produce a zero or negative issue")
    }

    func testFolioCarriesAShortDate() {
        XCTAssertEqual(present().folioDate, "Mon 7 Sep")
        XCTAssertEqual(present().folioIssue, "No. 1")
    }

    // MARK: - Held-back work

    func testHeldBackLineAppearsOnlyWhenWorkWasDeferred() {
        XCTAssertNil(present(obligations: [obligation("a", due: 3600)], sources: [okQuercus]).heldBackLine)

        let far = (0..<9).map { obligation("far\($0)", due: Double(6 + $0) * 86_400) }
        let edition = EditionBuilder(featuredLimit: 3, compactLimit: 2)
            .build(obligations: far, sources: [okQuercus], now: day(0))
        let morning = MorningEdition(edition: edition, news: [],
                                     cultural: CulturalDesk().selection(for: day(0), calendar: calendar),
                                     calendar: calendar)
        let p = EditionPresentation(morning: morning, firstEdition: day(0), calendar: calendar)
        XCTAssertEqual(p.heldBackLine, "4 further items held back until next week.")
    }

    func testSingleHeldItemReadsAsOne() {
        let far = (0..<6).map { obligation("far\($0)", due: Double(6 + $0) * 86_400) }
        let edition = EditionBuilder(featuredLimit: 3, compactLimit: 2)
            .build(obligations: far, sources: [okQuercus], now: day(0))
        let morning = MorningEdition(edition: edition, news: [],
                                     cultural: CulturalDesk().selection(for: day(0), calendar: calendar),
                                     calendar: calendar)
        let p = EditionPresentation(morning: morning, firstEdition: day(0), calendar: calendar)
        XCTAssertEqual(p.heldBackLine, "One further item held back until next week.")
    }

    // MARK: - Stop press

    func testStopPressCarriesOneNoticePerFailedSource() {
        let p = present(sources: [okQuercus, failedMail])
        XCTAssertEqual(p.stopPress.count, 1)
        XCTAssertTrue(p.stopPress[0].contains("School email unavailable"))
        XCTAssertTrue(p.stopPress[0].contains("yesterday"))
    }

    func testHealthyMorningHasNoStopPress() {
        XCTAssertTrue(present(sources: [okQuercus]).stopPress.isEmpty)
    }
}
