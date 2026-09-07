import Foundation

/// Anything that can contribute obligations to a morning.
public protocol ObligationSource: Sendable {
    var kind: SourceKind { get }
    func fetch(now: Date) async throws -> [Obligation]
}

/// What the app remembers between mornings.
///
/// Kept separate from the sources themselves: a source reports what it currently sees,
/// while this carries what the user has already said about those items and when each
/// source last actually worked.
public struct EditionMemory: Codable, Sendable, Equatable {
    /// Obligation id to the state the user put it in.
    public var states: [String: ObligationState]
    /// The last time each source answered successfully, which may be days ago.
    public var lastSuccessAt: [String: Date]

    public init(states: [String: ObligationState] = [:], lastSuccessAt: [String: Date] = [:]) {
        self.states = states
        self.lastSuccessAt = lastSuccessAt
    }

    public func lastSuccess(for kind: SourceKind) -> Date? { lastSuccessAt[kind.rawValue] }

    public mutating func recordSuccess(_ kind: SourceKind, at date: Date) {
        lastSuccessAt[kind.rawValue] = date
    }

    public mutating func record(_ state: ObligationState, for id: String) {
        states[id] = state
    }

    /// Drops remembered state for obligations no sources report any more, so the store
    /// does not grow without bound as coursework comes and goes.
    public mutating func forgetStates(notIn liveIDs: Set<String>) {
        states = states.filter { liveIDs.contains($0.key) }
    }
}

/// Gathers every source, then hands the result to the builder.
///
/// The rule this exists to enforce: one source failing must not remove the others, and
/// must never be quietly swallowed. A failure becomes a visible `SourceStatus`, which is
/// what stops the edition claiming you are caught up.
public struct EditionPipeline: Sendable {
    private let sources: [any ObligationSource]
    private let builder: EditionBuilder

    public init(sources: [any ObligationSource], builder: EditionBuilder = EditionBuilder()) {
        self.sources = sources
        self.builder = builder
    }

    public struct Result: Sendable {
        public let edition: Edition
        public let memory: EditionMemory
    }

    public func assemble(now: Date, memory: EditionMemory) async -> Result {
        // Sources are independent, so one being slow must not delay the rest.
        let outcomes = await withTaskGroup(
            of: (SourceKind, Swift.Result<[Obligation], SourceError>).self
        ) { group -> [(SourceKind, Swift.Result<[Obligation], SourceError>)] in
            for source in sources {
                group.addTask {
                    do {
                        return (source.kind, .success(try await source.fetch(now: now)))
                    } catch let error as SourceError {
                        return (source.kind, .failure(error))
                    } catch {
                        return (source.kind, .failure(.transport(error.localizedDescription)))
                    }
                }
            }
            var collected: [(SourceKind, Swift.Result<[Obligation], SourceError>)] = []
            for await outcome in group { collected.append(outcome) }
            return collected
        }

        var updated = memory
        var fetched: [Obligation] = []
        var statuses: [SourceStatus] = []

        // Sorted so an edition does not reshuffle just because tasks finished in a
        // different order.
        for (kind, outcome) in outcomes.sorted(by: { $0.0.rawValue < $1.0.rawValue }) {
            switch outcome {
            case .success(let obligations):
                fetched += obligations
                updated.recordSuccess(kind, at: now)
                statuses.append(
                    SourceStatus(kind: kind, outcome: .ok, lastSuccessAt: now, checkedAt: now)
                )
            case .failure(let error):
                // The previous success time is carried forward so the notice can say how
                // stale this source has become rather than just that it broke.
                statuses.append(
                    SourceStatus(
                        kind: kind,
                        outcome: .failed(reason: error.userFacingReason),
                        lastSuccessAt: memory.lastSuccess(for: kind),
                        checkedAt: now
                    )
                )
            }
        }

        // Reading an email or opening an assignment is not handling it, so what the user
        // said last time survives the refresh.
        let restored = fetched.map { obligation -> Obligation in
            guard let remembered = updated.states[obligation.id] else { return obligation }
            var copy = obligation
            copy.state = remembered
            return copy
        }

        updated.forgetStates(notIn: Set(fetched.map(\.id)))

        return Result(
            edition: builder.build(obligations: restored, sources: statuses, now: now),
            memory: updated
        )
    }
}

// MARK: - Source conformances

extension QuercusClient: ObligationSource {
    public var kind: SourceKind { .quercus }

    public func fetch(now: Date) async throws -> [Obligation] {
        try await fetchObligations(now: now)
    }
}
