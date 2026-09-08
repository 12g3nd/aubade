import Foundation
import CoreText

/// Registers the bundled faces and reports honestly on any that did not take.
///
/// Fonts ship as package resources rather than through the app's `UIAppFonts` plist, so
/// `AubadeUI` carries its own typography wherever it is used - app, preview or test - and
/// there is no second place to keep in sync.
public enum AubadeFonts {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var didRegister = false

    /// Registers every bundled font. Safe to call more than once.
    public static func register() {
        lock.lock()
        defer { lock.unlock() }
        guard !didRegister else { return }
        didRegister = true

        // `.process` may flatten the Resources tree or keep it, depending on the toolchain,
        // so look in both places rather than depending on which.
        let urls = bundledFontURLs()
        for url in urls {
            var error: Unmanaged<CFError>?
            // .process scope: the faces belong to this process, not the whole system.
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already-registered is the expected outcome on a second launch in the same
                // process and is not worth reporting; anything else is surfaced by `missing`.
                error?.release()
            }
        }
    }

    /// The requested faces that did not resolve after registration.
    ///
    /// A wrong PostScript name is otherwise invisible - the text simply renders in the
    /// system serif and nothing complains - so the app can call this and say so plainly.
    public static func missing() -> [String] {
        register()
        return FontFamily.allRequired.filter { name in
            CTFontCreateWithName(name as CFString, 12, nil).postScriptName != name
        }
    }

    public static var allResolved: Bool { missing().isEmpty }

    static func bundledFontURLs() -> [URL] {
        let flattened = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        let nested = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        return Array(Set(flattened + nested))
    }

    static func bundledLicenceNames() -> [String] {
        let flattened = Bundle.module.urls(forResourcesWithExtension: "txt", subdirectory: nil) ?? []
        let nested = Bundle.module.urls(forResourcesWithExtension: "txt", subdirectory: "Fonts") ?? []
        return Array(Set(flattened + nested)).map(\.lastPathComponent).sorted()
    }
}

private extension CTFont {
    var postScriptName: String {
        (CTFontCopyPostScriptName(self) as String?) ?? ""
    }
}
