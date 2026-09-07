import XCTest
@testable import AubadeCore

final class EditionBuilderTests: XCTestCase {
    // A fixed clock so every expectation below is exact rather than approximate.
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    func obligation(
        _ id: String,
        due: TimeInterval? = nil,
        confidence: Confidence = .stated,
        state: ObligationState = .open,
        source: SourceKind = .quercus
    ) -> Obligation {
        Obligation(
            id: id,
            title: id,
            source: source,
            dueAt: due.map { now.addingTimeInterval($0) },
            evidence: "test",
            confidence: confidence,
            state: state
        )
    }

    // MARK: - Urgency

    func testUrgencyBoundaries() {
        XCTAssertEqual(obligation("a", due: -60).urgency(at: now), .overdue)
        XCTAssertEqual(obligation("b", due: 3600).urgency(at: now), .dueSoon)
        XCTAssertEqual(obligation("c", due: 47 * 3600).urgency(at: now), .dueSoon)
        XCTAssertEqual(obligation("d", due: 72 * 3600).urgency(at: now), .startSoon)
        XCTAssertEqual(obligation("e", due: 20 * 24 * 3600).urgency(at: now), .undated)
        XCTAssertEqual(obligation("f").urgency(at: now), .undated, "no deadline must never be guessed into urgency")
    }

    func testRankingPutsMostUrgentFirst() {
        let built = EditionBuilder().build(
            obligations: [
                obligation("later", due: 10 * 24 * 3600),
                obligation("overdue", due: -3600),
                obligation("soon", due: 2 * 3600)
            ],
            sources: [], now: now
        )
        XCTAssertEqual(built.featured.map(\.id), ["overdue", "soon", "later"])
    }

    // MARK: - User state

    func testHandledAndDismissedDisappearButSnoozeReturns() {
        let built = EditionBuilder().build(
            obligations: [
                obligation("handled", due: 3600, state: .handled(at: now)),
                obligation("dismissed", due: 3600, state: .dismissed(at: now)),
                obligation("sleeping", due: 3600, state: .snoozed(until: now.addingTimeInterval(3600))),
                obligation("woken", due: 3600, state: .snoozed(until: now.addingTimeInterval(-1)))
            ],
            sources: [], now: now
        )
        XCTAssertEqual(built.allObligations.map(\.id), ["woken"])
    }

    // MARK: - Facts versus guesses

    func testInferredItemsAreNeverCountedAsObligations() {
        let built = EditionBuilder().build(
            obligations: [
                obligation("fact", due: 3600, confidence: .stated),
                obligation("guess", due: 3600, confidence: .inferred)
            ],
            sources: [], now: now
        )
        XCTAssertEqual(built.allObligations.map(\.id), ["fact"])
        XCTAssertEqual(built.candidates.map(\.id), ["guess"])
        XCTAssertFalse(built.canClaimComplete, "an outstanding guess still means we cannot say you are caught up")
    }

    // MARK: - Compression on an overloaded day

    func testCompressionNeverDefersNearTermWork() {
        // Twelve urgent items and a tight budget: none of them may be held back.
        let urgent = (0..<12).map { obligation("urgent\($0)", due: Double($0) * 3600) }
        let built = EditionBuilder(featuredLimit: 3, compactLimit: 2).build(
            obligations: urgent, sources: [], now: now
        )
        XCTAssertTrue(built.deferred.isEmpty, "near-term deadlines must survive compression")
        XCTAssertEqual(built.allObligations.count, 12)
        XCTAssertEqual(built.featured.count, 3, "only three items get explanations")
    }

    func testNonUrgentWorkIsDeferredOnceBudgetIsSpent() {
        let items = (0..<10).map { obligation("far\($0)", due: Double(5 + $0) * 24 * 3600) }
        let built = EditionBuilder(featuredLimit: 3, compactLimit: 2).build(
            obligations: items, sources: [], now: now
        )
        XCTAssertEqual(built.featured.count, 3)
        XCTAssertEqual(built.compact.count, 2)
        XCTAssertEqual(built.deferred.count, 5)
        for item in built.deferred {
            XCTAssertFalse(item.mustRemainVisible(at: now))
        }
    }

    // MARK: - The load-bearing honesty rule

    func testFailedSourceForbidsClaimingComplete() {
        let failed = SourceStatus(
            kind: .schoolMail,
            outcome: .failed(reason: "timeout"),
            lastSuccessAt: now.addingTimeInterval(-86_400),
            checkedAt: now
        )
        let built = EditionBuilder().build(obligations: [], sources: [failed], now: now)

        XCTAssertTrue(built.allObligations.isEmpty)
        XCTAssertFalse(built.canClaimComplete, "finding nothing is not the same as there being nothing")
        XCTAssertEqual(built.summaryLine, "Nothing found in the sources that answered.")
        XCTAssertEqual(built.notices.count, 1)
    }

    func testEmptyEditionWithHealthySourcesMayClaimComplete() {
        let ok = SourceStatus(kind: .quercus, outcome: .ok, lastSuccessAt: now, checkedAt: now)
        let built = EditionBuilder().build(obligations: [], sources: [ok], now: now)
        XCTAssertTrue(built.canClaimComplete)
        XCTAssertEqual(built.summaryLine, "Nothing needs you this morning.")
    }

    func testDeferredWorkAlsoBlocksClaimingComplete() {
        let items = (0..<10).map { obligation("far\($0)", due: Double(5 + $0) * 24 * 3600) }
        let built = EditionBuilder(featuredLimit: 1, compactLimit: 1).build(
            obligations: items, sources: [], now: now
        )
        XCTAssertFalse(built.deferred.isEmpty)
        XCTAssertFalse(built.canClaimComplete)
    }

    // MARK: - Notices

    func testNoticeNamesSourceAndWhenItLastWorked() {
        let status = SourceStatus(
            kind: .schoolMail,
            outcome: .failed(reason: "401"),
            lastSuccessAt: now.addingTimeInterval(-86_400),
            checkedAt: now
        )
        let notice = status.notice(relativeTo: now)
        XCTAssertNotNil(notice)
        XCTAssertTrue(notice!.contains("School email unavailable"))
        XCTAssertTrue(notice!.contains("yesterday"), "a vague warning teaches the reader to ignore it")
    }

    func testNoticeUsesTheEditionsClockNotTheSystemClock() {
        // Regression: the notice once called isDateInYesterday, which silently compares
        // against the real system date and ignored the clock it was handed.
        func notice(daysAgo: Double) -> String {
            SourceStatus(
                kind: .personalMail,
                outcome: .failed(reason: "offline"),
                lastSuccessAt: now.addingTimeInterval(-daysAgo * 86_400),
                checkedAt: now
            ).notice(relativeTo: now)!
        }
        XCTAssertTrue(notice(daysAgo: 0).contains("today"))
        XCTAssertTrue(notice(daysAgo: 1).contains("yesterday"))
        let older = notice(daysAgo: 5)
        XCTAssertFalse(older.contains("today"))
        XCTAssertFalse(older.contains("yesterday"))
    }

    func testNoticeWithoutAnySuccessSaysSo() {
        let status = SourceStatus(
            kind: .quercus, outcome: .failed(reason: "bad token"),
            lastSuccessAt: nil, checkedAt: now
        )
        XCTAssertTrue(status.notice(relativeTo: now)!.contains("never synced"))
    }

    func testHealthySourceProducesNoNotice() {
        let status = SourceStatus(kind: .quercus, outcome: .ok, lastSuccessAt: now, checkedAt: now)
        XCTAssertNil(status.notice(relativeTo: now))
    }
}
