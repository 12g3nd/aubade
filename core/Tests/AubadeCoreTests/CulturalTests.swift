import XCTest
@testable import AubadeCore

final class CulturalDeskTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    let desk = CulturalDesk()

    /// 7am local on consecutive days. Built from components rather than by adding seconds
    /// to an epoch: the selection turns over at local midnight, so a fixture that happens
    /// to land in the late afternoon makes "later the same day" cross into tomorrow.
    func day(_ offset: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 7 + offset
        components.hour = 7
        return calendar.date(from: components)!
    }

    // MARK: - The property the whole design rests on

    func testSelectionIsStableWithinTheSameDay() {
        // The edition is prepared when the app opens. Reopening it at lunch must show the
        // same morning rather than rerolling the poem.
        let morning = day(0)                                  // 07:00 local
        let afternoon = morning.addingTimeInterval(10 * 3600) // 17:00, same local day

        let a = desk.selection(for: morning, calendar: calendar)
        let b = desk.selection(for: afternoon, calendar: calendar)

        XCTAssertEqual(a.item?.id, b.item?.id)
        XCTAssertEqual(a.curiosity?.id, b.curiosity?.id)
    }

    func testSelectionTurnsOverAtLocalMidnightNotAtAFixedOffset() {
        let lateTonight = day(0).addingTimeInterval(16 * 3600)  // 23:00 local
        let earlyTomorrow = day(0).addingTimeInterval(18 * 3600) // 01:00 local, next day

        XCTAssertNotEqual(
            desk.selection(for: lateTonight, calendar: calendar).item?.id,
            desk.selection(for: earlyTomorrow, calendar: calendar).item?.id,
            "a new day should bring a new selection, and midnight is where it changes"
        )
    }

    func testSelectionChangesFromOneDayToTheNext() {
        let today = desk.selection(for: day(0), calendar: calendar)
        let tomorrow = desk.selection(for: day(1), calendar: calendar)
        XCTAssertNotEqual(today.item?.id, tomorrow.item?.id)
        XCTAssertNotEqual(today.curiosity?.id, tomorrow.curiosity?.id)
    }

    func testSelectionIsPurelyAFunctionOfTheDate() {
        // No randomness anywhere: two desks built independently must agree.
        let other = CulturalDesk()
        for offset in 0..<20 {
            XCTAssertEqual(
                desk.selection(for: day(offset), calendar: calendar).item?.id,
                other.selection(for: day(offset), calendar: calendar).item?.id
            )
        }
    }

    // MARK: - Rotation

    func testPoetryLeadsButShorterFormsRotateThrough() {
        let kinds = (0..<12).compactMap {
            desk.selection(for: day($0), calendar: calendar).item?.kind
        }
        XCTAssertEqual(kinds.count, 12)
        XCTAssertTrue(Set(kinds).count >= 2, "the slot must not be the same shape every morning")
        let poems = kinds.filter { $0 == .poem }.count
        XCTAssertGreaterThan(poems, kinds.count / 3, "the slot should lead with poetry")
    }

    func testRotationWorksThroughTheWholeLibraryRatherThanRepeatingOne() {
        let ids = (0..<40).compactMap { desk.selection(for: day($0), calendar: calendar).item?.id }
        XCTAssertGreaterThan(Set(ids).count, 4, "a long run must not sit on a couple of items")
    }

    func testCuriositiesCycleThroughEveryEntry() {
        let count = CulturalLibrary.curiosities.count
        let ids = (0..<count).compactMap {
            desk.selection(for: day($0), calendar: calendar).curiosity?.id
        }
        XCTAssertEqual(Set(ids).count, count, "one full cycle should visit each site once")
    }

    func testGamesAreFixedRatherThanRotated() {
        let a = desk.selection(for: day(0), calendar: calendar).games
        let b = desk.selection(for: day(9), calendar: calendar).games
        XCTAssertEqual(a, b, "the games are a fixed set, not a surprise")
        XCTAssertFalse(a.isEmpty)
    }

    // MARK: - Robustness

    func testEmptyLibraryYieldsAnEmptySlotRatherThanCrashing() {
        let bare = CulturalDesk(items: [], curiosities: [], games: [])
        let selection = bare.selection(for: day(0), calendar: calendar)
        XCTAssertNil(selection.item)
        XCTAssertNil(selection.curiosity)
        XCTAssertTrue(selection.games.isEmpty)
    }

    func testMissingKindFallsBackRatherThanShowingNothing() {
        // A library with no poems must still fill the slot on a poem day.
        let quotesOnly = CulturalDesk(
            items: [CulturalItem(id: "q", kind: .quote, text: "Only this.", attribution: "Someone")],
            curiosities: [],
            games: []
        )
        for offset in 0..<8 {
            XCTAssertNotNil(quotesOnly.selection(for: day(offset), calendar: calendar).item)
        }
    }

    func testDatesBeforeTheReferenceDoNotProduceANegativeIndex() {
        let old = Date(timeIntervalSince1970: -5 * 86_400)
        XCTAssertNotNil(desk.selection(for: old, calendar: calendar).item)
    }

    // MARK: - Library invariants

    func testEveryPoemIsShortEnoughForAFiniteEdition() {
        // A probe of PoetryDB returned a 62KB poem. Bundled content must stay short.
        for item in CulturalLibrary.items where item.kind == .poem {
            let lines = item.text.split(separator: "\n").count
            XCTAssertLessThanOrEqual(lines, 16, "\(item.id) is too long for a ten-minute edition")
        }
    }

    func testEveryItemCarriesTextAndPoemsAndQuotesAreAttributed() {
        for item in CulturalLibrary.items {
            XCTAssertFalse(item.text.isEmpty, "\(item.id) has no text")
            if item.kind != .fact {
                XCTAssertNotNil(item.attribution, "\(item.id) must credit its author")
            }
        }
    }

    func testLibraryIdentifiersAreUnique() {
        let ids = CulturalLibrary.items.map(\.id)
            + CulturalLibrary.curiosities.map(\.id)
            + CulturalLibrary.games.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate ids would break rotation and saving")
    }

    func testEveryLinkIsHTTPS() {
        for url in CulturalLibrary.curiosities.map(\.url) + CulturalLibrary.games.map(\.url) {
            XCTAssertEqual(url.scheme, "https", "\(url) is not secure")
        }
    }
}
