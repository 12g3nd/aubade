import Foundation

/// The small amount of file access the core needs, behind a protocol so retention and
/// pruning can be tested without touching a disk.
public protocol FileStore: Sendable {
    func read(_ name: String) throws -> Data?
    func write(_ data: Data, to name: String) throws
    func delete(_ name: String) throws
    func listNames() throws -> [String]
}

/// A `FileStore` held in memory, for tests.
public final class InMemoryFileStore: FileStore, @unchecked Sendable {
    private let lock = NSLock()
    private var files: [String: Data] = [:]

    public init(files: [String: Data] = [:]) { self.files = files }

    public func read(_ name: String) throws -> Data? { lock.withLock { files[name] } }
    public func write(_ data: Data, to name: String) throws { lock.withLock { files[name] = data } }
    public func delete(_ name: String) throws { _ = lock.withLock { files.removeValue(forKey: name) } }
    public func listNames() throws -> [String] { lock.withLock { Array(files.keys).sorted() } }
    public var count: Int { lock.withLock { files.count } }
}

/// A `FileStore` backed by a directory on the device.
public struct DirectoryFileStore: FileStore {
    private let directory: URL

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func read(_ name: String) throws -> Data? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func write(_ data: Data, to name: String) throws {
        // Complete-unless-open keeps stored mornings unreadable while the phone is locked,
        // which matters because they are derived from mail and coursework.
        try data.write(
            to: directory.appendingPathComponent(name),
            options: [.atomic, .completeFileProtectionUnlessOpen]
        )
    }

    public func delete(_ name: String) throws {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public func listNames() throws -> [String] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        return names.sorted()
    }
}

/// Stores past mornings, the things the reader kept, and what the app remembers.
///
/// Retention is the point. Thirty days of editions is a deliberate limit rather than an
/// accident of never deleting anything: mornings are derived from mail and coursework, and
/// an archive of those should not accumulate silently. Explicitly saved items are public
/// by construction and outlive the window.
public struct EditionArchive: Sendable {
    public static let editionPrefix = "edition-"
    public static let editionSuffix = ".json"
    public static let savedName = "saved.json"
    public static let memoryName = "memory.json"

    private let store: FileStore
    public let retentionDays: Int

    public init(store: FileStore, retentionDays: Int = 30) {
        self.store = store
        self.retentionDays = retentionDays
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Editions

    public func save(_ morning: MorningEdition) throws {
        try store.write(encoder.encode(morning), to: Self.name(for: morning.id))
    }

    public func morning(for dayKey: String) throws -> MorningEdition? {
        guard let data = try store.read(Self.name(for: dayKey)) else { return nil }
        return try decoder.decode(MorningEdition.self, from: data)
    }

    /// Every stored morning, newest first. Unreadable files are skipped rather than
    /// throwing: one corrupt morning must not cost the reader the archive.
    public func allMornings() throws -> [MorningEdition] {
        try store.listNames()
            .filter { $0.hasPrefix(Self.editionPrefix) && $0.hasSuffix(Self.editionSuffix) }
            .compactMap { name in
                guard let data = try? store.read(name) else { return nil }
                return try? decoder.decode(MorningEdition.self, from: data)
            }
            .sorted { $0.date > $1.date }
    }

    /// Deletes mornings older than the retention window. Returns what it removed.
    @discardableResult
    public func prune(now: Date, calendar: Calendar = .current) throws -> [String] {
        let cutoff = calendar.startOfDay(for: now.addingTimeInterval(-Double(retentionDays) * 86_400))
        var removed: [String] = []
        for morning in try allMornings() where morning.date < cutoff {
            try store.delete(Self.name(for: morning.id))
            removed.append(morning.id)
        }
        return removed
    }

    // MARK: - Saved items

    public func savedItems() throws -> [SavedItem] {
        guard let data = try store.read(Self.savedName) else { return [] }
        return (try? decoder.decode([SavedItem].self, from: data)) ?? []
    }

    /// Saving is idempotent: keeping the same story twice keeps it once.
    public func save(item: SavedItem) throws {
        var items = try savedItems()
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        try store.write(encoder.encode(items), to: Self.savedName)
    }

    public func removeSavedItem(id: String) throws {
        let items = try savedItems().filter { $0.id != id }
        try store.write(encoder.encode(items), to: Self.savedName)
    }

    // MARK: - Memory

    public func memory() throws -> EditionMemory {
        guard let data = try store.read(Self.memoryName) else { return EditionMemory() }
        return (try? decoder.decode(EditionMemory.self, from: data)) ?? EditionMemory()
    }

    public func save(memory: EditionMemory) throws {
        try store.write(encoder.encode(memory), to: Self.memoryName)
    }

    // MARK: -

    static func name(for dayKey: String) -> String {
        "\(editionPrefix)\(dayKey)\(editionSuffix)"
    }
}
