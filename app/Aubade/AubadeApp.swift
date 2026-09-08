import SwiftUI
import AubadeCore
import AubadeUI

@main
struct AubadeApp: App {
    @StateObject private var store = MorningStore(
        archive: EditionArchive(store: AubadeApp.editionsDirectory()),
        credentials: KeychainCredentialStore()
    )

    var body: some Scene {
        WindowGroup {
            AubadeRootView(store: store)
        }
    }

    /// Editions live in Application Support rather than Documents: they are the app's own
    /// working store, not files the reader manages. Exports are what leave the app.
    private static func editionsDirectory() -> FileStore {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let directory = base.appendingPathComponent("Editions", isDirectory: true)
        if let store = try? DirectoryFileStore(directory: directory) { return store }
        // A store that cannot be created must not take the morning down with it: the
        // edition still builds, it simply is not remembered.
        return InMemoryFileStore()
    }
}
