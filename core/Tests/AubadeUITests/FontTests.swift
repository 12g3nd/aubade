import XCTest
import CoreText
import AubadeCore
@testable import AubadeUI

/// Guards the failure mode that has no symptom.
///
/// A wrong PostScript name does not crash or warn - the text renders in the system serif
/// and the app looks plausible but is not the design. Every name in `FontFamily` was wrong
/// when first written, because they were guessed from the family name rather than read from
/// the files, and nothing caught it until the files were parsed by hand.
final class FontTests: XCTestCase {
    func testEveryRequiredFaceIsBundledAndResolves() {
        AubadeFonts.register()
        XCTAssertEqual(
            AubadeFonts.missing(), [],
            "these PostScript names do not resolve; SwiftUI would fall back to the system face silently"
        )
    }

    func testFontFilesShipInsideThePackage() {
        XCTAssertGreaterThanOrEqual(
            AubadeFonts.bundledFontURLs().count, 4,
            "the bundled faces are missing from the package resources"
        )
    }

    /// The OFL requires the licence to travel with the fonts.
    func testLicencesTravelWithTheFonts() {
        let names = AubadeFonts.bundledLicenceNames()
        XCTAssertTrue(names.contains("OFL-Newsreader.txt"), "found: \(names)")
        XCTAssertTrue(names.contains("OFL-IBMPlexMono.txt"), "found: \(names)")
    }

    func testTheAlarmColourIsReachableOnlyThroughMeaning() {
        // Not a compile-time guarantee, but it pins the intent: the semantic accessors
        // return the alarm colour exactly when something is late or unconfirmed.
        let theme = Theme.day
        XCTAssertEqual(theme.color(for: .overdue), theme.doubtColor)
        XCTAssertNotEqual(theme.color(for: .dueSoon), theme.doubtColor)
        XCTAssertNotEqual(theme.color(for: .startSoon), theme.doubtColor)
        XCTAssertEqual(theme.color(for: .inferred), theme.doubtColor)
        XCTAssertNotEqual(theme.color(for: .stated), theme.doubtColor)
    }

    func testNightEditionIsNotAnInversionOfTheDay() {
        XCTAssertNotEqual(Theme.night.palette.newsprint, Theme.day.palette.ink)
        XCTAssertNotEqual(Theme.night.palette.ink, Theme.day.palette.newsprint)
    }
}
