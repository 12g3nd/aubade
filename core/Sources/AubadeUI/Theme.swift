import SwiftUI
import AubadeCore

/// The broadsheet's ink.
///
/// `alarm` is deliberately not public. Red means one thing in this edition - something is
/// late, or something is unconfirmed - and the only way to reach it is through the semantic
/// accessors on `Theme`. A palette that hands out a red anyone can use for emphasis stops
/// meaning anything by the third screen.
public struct Palette: Sendable {
    public let newsprint: Color
    public let ink: Color
    public let inkMuted: Color
    public let rule: Color
    /// Dates, sources, section marks. The quiet structural colour.
    public let spot: Color
    let alarm: Color
    public let stamp: Color

    public static let day = Palette(
        newsprint: Color(red: 0.914, green: 0.914, blue: 0.894),   // #E9E9E4
        ink:       Color(red: 0.102, green: 0.102, blue: 0.094),   // #1A1A18
        inkMuted:  Color(red: 0.290, green: 0.290, blue: 0.267),   // #4A4A44
        rule:      Color(red: 0.765, green: 0.765, blue: 0.737),   // #C3C3BC
        spot:      Color(red: 0.122, green: 0.227, blue: 0.373),   // #1F3A5F
        alarm:     Color(red: 0.549, green: 0.184, blue: 0.149),   // #8C2F26
        stamp:     Color(red: 0.482, green: 0.482, blue: 0.455)    // #7B7B74
    )

    /// A night edition rather than an inversion.
    ///
    /// Inverting newsprint gives a grey app. A paper printed for the dark is its own thing:
    /// a warm near-black that reads as ink rather than screen, paper-white text, and both
    /// the spot and the alarm lifted until they carry on a dark ground.
    public static let night = Palette(
        newsprint: Color(red: 0.075, green: 0.075, blue: 0.067),   // #131311
        ink:       Color(red: 0.894, green: 0.886, blue: 0.851),   // #E4E2D9
        inkMuted:  Color(red: 0.588, green: 0.584, blue: 0.545),   // #96958B
        rule:      Color(red: 0.180, green: 0.180, blue: 0.161),   // #2E2E29
        spot:      Color(red: 0.498, green: 0.639, blue: 0.800),   // #7FA3CC
        alarm:     Color(red: 0.878, green: 0.451, blue: 0.416),   // #E0736A
        stamp:     Color(red: 0.427, green: 0.424, blue: 0.396)    // #6D6C65
    )
}

/// PostScript names of the bundled faces.
///
/// These are read from the files rather than guessed. Newsreader ships as a variable font
/// whose named instances are `NewsreaderRoman-*` and `NewsreaderItalic-*` - not the
/// `Newsreader-*` the family name suggests. A wrong name here is invisible: SwiftUI falls
/// back to the system serif without complaint, so the app looks fine and simply is not the
/// design. `AubadeFonts.missing` exists to make that failure speak up, and a test asserts
/// every name below actually resolves from the bundled files.
public enum FontFamily {
    public static let editorialRegular = "NewsreaderRoman-Regular"
    public static let editorialSemibold = "NewsreaderRoman-SemiBold"
    public static let editorialBold = "NewsreaderRoman-Bold"
    public static let editorialItalic = "NewsreaderItalic-Regular"
    public static let utility = "IBMPlexMono-Regular"
    public static let utilityMedium = "IBMPlexMono-Medium"

    public static let allRequired = [
        editorialRegular, editorialSemibold, editorialBold, editorialItalic,
        utility, utilityMedium
    ]
}

/// Typographic roles, each tied to a system text style so Dynamic Type still scales them.
///
/// `Font.custom(_:size:relativeTo:)` is what makes that work; a custom font given a fixed
/// size ignores the reader's text-size setting entirely.
public struct Typography: Sendable {
    public init() {}

    public var lead: Font { .custom(FontFamily.editorialBold, size: 23, relativeTo: .title2) }
    public var leadSecondary: Font { .custom(FontFamily.editorialBold, size: 18, relativeTo: .title3) }
    public var featureTitle: Font { .custom(FontFamily.editorialBold, size: 25, relativeTo: .title2) }
    public var standfirst: Font { .custom(FontFamily.editorialRegular, size: 13, relativeTo: .callout) }
    public var brief: Font { .custom(FontFamily.editorialRegular, size: 12.5, relativeTo: .footnote) }
    public var briefEmphasis: Font { .custom(FontFamily.editorialBold, size: 12.5, relativeTo: .footnote) }
    public var storyTitle: Font { .custom(FontFamily.editorialBold, size: 13, relativeTo: .footnote) }
    public var storyBody: Font { .custom(FontFamily.editorialRegular, size: 12, relativeTo: .caption) }
    public var verse: Font { .custom(FontFamily.editorialItalic, size: 13, relativeTo: .callout) }
    public var featureVerse: Font { .custom(FontFamily.editorialItalic, size: 15, relativeTo: .body) }
    public var masthead: Font { .custom(FontFamily.editorialBold, size: 31, relativeTo: .largeTitle) }

    // Utility face: letter-spaced caps doing the structural work.
    public var folio: Font { .custom(FontFamily.utility, size: 9, relativeTo: .caption2) }
    public var folioEmphasis: Font { .custom(FontFamily.utilityMedium, size: 9, relativeTo: .caption2) }
    public var kicker: Font { .custom(FontFamily.utility, size: 9, relativeTo: .caption2) }
    public var sectionHead: Font { .custom(FontFamily.utility, size: 9.5, relativeTo: .caption2) }
    public var meta: Font { .custom(FontFamily.utility, size: 10, relativeTo: .caption2) }
    public var footnote: Font { .custom(FontFamily.utility, size: 10, relativeTo: .caption2) }
    public var stamp: Font { .custom(FontFamily.utility, size: 7.5, relativeTo: .caption2) }
}

public struct Theme: Sendable {
    public let palette: Palette
    public let type: Typography

    public init(palette: Palette, type: Typography = Typography()) {
        self.palette = palette
        self.type = type
    }

    public static let day = Theme(palette: .day)
    public static let night = Theme(palette: .night)

    public static func forScheme(_ scheme: ColorScheme) -> Theme {
        scheme == .dark ? .night : .day
    }

    // MARK: - Semantic colour
    //
    // The only routes to the alarm colour. Each answers a question about meaning rather
    // than handing out a swatch.

    /// Overdue work is the only urgency that earns red. Everything else is dated in the
    /// spot colour, because a deadline three days out is information, not an alarm.
    public func color(for urgency: Urgency) -> Color {
        urgency == .overdue ? palette.alarm : palette.spot
    }

    /// An inferred item is a question, and questions are marked in red so they are never
    /// mistaken for the facts above them.
    public func color(for confidence: Confidence) -> Color {
        confidence == .inferred ? palette.alarm : palette.spot
    }

    /// A source that failed, a count that cannot be trusted, a stop-press rule.
    public var doubtColor: Color { palette.alarm }

    /// Handled work: struck through and stepped back, never coloured.
    public var handledColor: Color { palette.stamp }
}

// MARK: - Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .day
}

public extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

public extension View {
    /// Applies the edition's theme, following the reader's light or dark setting.
    func broadsheetTheme(_ scheme: ColorScheme) -> some View {
        environment(\.theme, .forScheme(scheme))
    }
}
