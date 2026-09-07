import Foundation

/// The bundled cultural content.
///
/// Ships with the app rather than being fetched. Three reasons this is the default rather
/// than a fallback: the edition must open with no signal; a poetry service being down
/// should not cost you the one part of the morning that is not work; and a probe of
/// PoetryDB returned a single 62KB poem, which would quietly break the promise that the
/// edition is finite. Everything here is short by construction.
///
/// Poems are pre-1900 and public domain. Anything added later must be too.
public enum CulturalLibrary {
    public static let items: [CulturalItem] = [
        CulturalItem(
            id: "poem-dickinson-nobody",
            kind: .poem,
            title: "I'm Nobody! Who are you?",
            text: """
            I'm Nobody! Who are you?
            Are you - Nobody - too?
            Then there's a pair of us!
            Don't tell! they'd advertise - you know!

            How dreary - to be - Somebody!
            How public - like a Frog -
            To tell one's name - the livelong June -
            To an admiring Bog!
            """,
            attribution: "Emily Dickinson"
        ),
        CulturalItem(
            id: "poem-blake-sick-rose",
            kind: .poem,
            title: "The Sick Rose",
            text: """
            O Rose thou art sick.
            The invisible worm,
            That flies in the night
            In the howling storm:

            Has found out thy bed
            Of crimson joy:
            And his dark secret love
            Does thy life destroy.
            """,
            attribution: "William Blake"
        ),
        CulturalItem(
            id: "poem-dickinson-hope",
            kind: .poem,
            title: "\"Hope\" is the thing with feathers",
            text: """
            "Hope" is the thing with feathers -
            That perches in the soul -
            And sings the tune without the words -
            And never stops - at all -

            And sweetest - in the Gale - is heard -
            And sore must be the storm -
            That could abash the little Bird
            That kept so many warm -
            """,
            attribution: "Emily Dickinson"
        ),
        CulturalItem(
            id: "poem-rossetti-remember",
            kind: .poem,
            title: "Remember",
            text: """
            Remember me when I am gone away,
            Gone far away into the silent land;
            When you can no more hold me by the hand,
            Nor I half turn to go yet turning stay.
            Remember me when no more day by day
            You tell me of our future that you plann'd:
            Only remember me; you understand
            It will be late to counsel then or pray.
            """,
            attribution: "Christina Rossetti"
        ),
        CulturalItem(
            id: "poem-whitman-astronomer",
            kind: .poem,
            title: "When I Heard the Learn'd Astronomer",
            text: """
            When I heard the learn'd astronomer,
            When the proofs, the figures, were ranged in columns before me,
            When I was shown the charts and diagrams, to add, divide, and measure them,
            When I sitting heard the astronomer where he lectured with much applause in the lecture-room,
            How soon unaccountable I became tired and sick,
            Till rising and gliding out I wander'd off by myself,
            In the mystical moist night-air, and from time to time,
            Look'd up in perfect silence at the stars.
            """,
            attribution: "Walt Whitman"
        ),

        CulturalItem(
            id: "quote-hoover-next",
            kind: .quote,
            text: "Wisdom consists not so much in knowing what to do in the ultimate as knowing what to do next.",
            attribution: "Herbert Hoover"
        ),
        CulturalItem(
            id: "quote-eliot-still",
            kind: .quote,
            text: "We shall not cease from exploration, and the end of all our exploring will be to arrive where we started and know the place for the first time.",
            attribution: "T. S. Eliot"
        ),
        CulturalItem(
            id: "quote-hamming-important",
            kind: .quote,
            text: "If you do not work on an important problem, it is unlikely you will do important work.",
            attribution: "Richard Hamming"
        ),
        CulturalItem(
            id: "quote-woolf-ordinary",
            kind: .quote,
            text: "Examine for a moment an ordinary mind on an ordinary day.",
            attribution: "Virginia Woolf"
        ),

        CulturalItem(
            id: "fact-octopus-hearts",
            kind: .fact,
            text: "An octopus has three hearts. Two pump blood through the gills; the third stops beating whenever it swims, which is part of why they would usually rather walk."
        ),
        CulturalItem(
            id: "fact-honey",
            kind: .fact,
            text: "Honey does not spoil. Its low water content and acidity make it inhospitable to bacteria, and jars found in Egyptian tombs were still edible thousands of years later."
        ),
        CulturalItem(
            id: "fact-shortest-war",
            kind: .fact,
            text: "The shortest recorded war lasted about 38 minutes: the Anglo-Zanzibar War of 1896 was over before most of the participants had finished arriving."
        ),
        CulturalItem(
            id: "fact-toronto-ravines",
            kind: .fact,
            text: "Toronto sits on roughly 300 kilometres of ravine, a buried river system that is why the city is threaded with forest you cannot see from the street grid."
        )
    ]

    /// Chosen because each is genuinely worth the detour and has been online for years.
    /// A random redirect service would be easier and much worse.
    public static let curiosities: [Curiosity] = [
        Curiosity(
            id: "deep-sea",
            title: "The Deep Sea",
            url: URL(string: "https://neal.fun/deep-sea/")!,
            note: "Scroll down through the ocean. It takes much longer than you expect."
        ),
        Curiosity(
            id: "radio-garden",
            title: "Radio Garden",
            url: URL(string: "https://radio.garden/")!,
            note: "Spin a globe and listen to whatever local radio is playing right now."
        ),
        Curiosity(
            id: "wiby",
            title: "Wiby",
            url: URL(string: "https://wiby.me/")!,
            note: "A search engine for the small, hand-made web that predates the feed."
        ),
        Curiosity(
            id: "zoomquilt",
            title: "The Zoomquilt",
            url: URL(string: "https://zoomquilt.org/")!,
            note: "A painting that zooms into itself forever."
        ),
        Curiosity(
            id: "window-swap",
            title: "WindowSwap",
            url: URL(string: "https://www.window-swap.com/")!,
            note: "Look out of a stranger's window somewhere else in the world."
        ),
        Curiosity(
            id: "pointer-pointer",
            title: "Pointer Pointer",
            url: URL(string: "https://pointerpointer.com/")!,
            note: "Put your cursor anywhere. Someone is pointing at it."
        ),
        Curiosity(
            id: "soft-murmur",
            title: "A Soft Murmur",
            url: URL(string: "https://asoftmurmur.com/")!,
            note: "Mix rain, waves and a distant coffee shop into something to work under."
        ),
        Curiosity(
            id: "useless-web",
            title: "The Useless Web",
            url: URL(string: "https://theuselessweb.com/")!,
            note: "One button, one pointless destination. Occasionally sublime."
        )
    ]

    public static let games: [GameLink] = [
        GameLink(id: "wordle", name: "Wordle",
                 url: URL(string: "https://www.nytimes.com/games/wordle/index.html")!),
        GameLink(id: "connections", name: "Connections",
                 url: URL(string: "https://www.nytimes.com/games/connections")!),
        GameLink(id: "mini", name: "The Mini",
                 url: URL(string: "https://www.nytimes.com/crosswords/game/mini")!),
        GameLink(id: "spelling-bee", name: "Spelling Bee",
                 url: URL(string: "https://www.nytimes.com/puzzles/spelling-bee")!)
    ]
}
