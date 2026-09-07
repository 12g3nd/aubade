import XCTest
@testable import AubadeCore

/// A source with a scripted outcome, so partial-failure behaviour can be tested exactly.
struct FakeSource: ObligationSource {
    let kind: SourceKind
    let outcome: Result<[Obligation], SourceError>
    var delay: Duration = .zero

    func fetch(now: Date) async throws -> [Obligation] {
        if delay != .zero { try? await Task.sleep(for: delay) }
        switch outcome {
        case .success(let items): return items
        case .failure(let error): throw error
        }
    }
}

final class EditionPipelineTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    func obligation(_ id: String, source: SourceKind = .quercus, due: TimeInterval = 3600) -> Obligation {
        Obligation(
            id: id, title: id, source: source,
            dueAt: now.addingTimeInterval(due),
            evidence: "test", confidence: .stated
        )
    }

    // MARK: - Partial failure

    func testOneSourceFailingDoesNotRemoveTheOthers() async {
        let pipeline = EditionPipeline(sources: [
            FakeSource(kind: .quercus, outcome: .success([obligation("essay")])),
            FakeSource(kind: .schoolMail, outcome: .failure(.unauthorized))
        ])

        let result = await pipeline.assemble(now: now, memory: EditionMemory())

        XCTAssertEqual(result.edition.allObligations.map(\.id), ["essay"],
                       "a working source must still be reported")
        XCTAssertEqual(result.edition.failedSources.count, 1)
        XCTAssertFalse(result.edition.canClaimComplete,
                       "a failed source must block any claim of being caught up")
        XCTAssertTrue(result.edition.notices[0].contains("School email unavailable"))
    }

    func testEverySourceFailingStillProducesAnHonestEdition() async {
        let pipeline = EditionPipeline(sources: [
            FakeSource(kind: .quercus, outcome: .failure(.transport("offline"))),
            FakeSource(kind: .schoolMail, outcome: .failure(.transport("offline")))
        ])

        let result = await pipeline.assemble(now: now, memory: EditionMemory())

        XCTAssertTrue(result.edition.allObligations.isEmpty)
        XCTAssertFalse(result.edition.canClaimComplete)
        XCTAssertEqual(result.edition.summaryLine, "Nothing found in the sources that answered.")
        XCTAssertEqual(result.edition.notices.count, 2)
    }

    func testAllSourcesHealthyAndEmptyMayClaimComplete() async {
        let pipeline = EditionPipeline(sources: [
            FakeSource(kind: .quercus, outcome: .success([]))
        ])
        let result = await pipeline.assemble(now: now, memory: EditionMemory())
        XCTAssertTrue(result.edition.canClaimComplete)
        XCTAssertEqual(result.edition.summaryLine, "Nothing needs you this morning.")
    }

    // MARK: - Staleness

    func testFailureCarriesForwardTheLastSuccessSoStalenessIsVisible() async {
        let yesterday = now.addingTimeInterval(-86_400)
        var memory = EditionMemory()
        memory.recordSuccess(.schoolMail, at: yesterday)

        let pipeline = EditionPipeline(sources: [
            FakeSource(kind: .schoolMail, outcome: .failure(.transport("timeout")))
        ])
        let result = await pipeline.assemble(now: now, memory: memory)

        XCTAssertTrue(result.edition.notices[0].contains("yesterday"))
        XCTAssertEqual(result.memory.lastSuccess(for: .schoolMail), yesterday,
                       "a failure must not overwrite the last time the source worked")
    }

    func testSuccessRecordsTheTimeForNextMorning() async {
        let pipeline = EditionPipeline(sources: [
            FakeSource(kind: .quercus, outcome: .success([obligation("a")]))
        ])
        let result = await pipeline.assemble(now: now, memory: EditionMemory())
        XCTAssertEqual(result.memory.lastSuccess(for: .quercus), now)
    }

    // MARK: - User decisions survive a refresh

    func testHandledWorkStaysHandledAfterRefetching() async {
        var memory = EditionMemory()
        memory.record(.handled(at: now.addingTimeInterval(-60)), for: "essay")

        // The source still reports it, because Quercus does not know the user dealt with it.
        let pipeline = EditionPipeline(sources: [
            FakeSource(kind: .quercus, outcome: .success([obligation("essay"), obligation("lab")]))
        ])
        let result = await pipeline.assemble(now: now, memory: memory)

        XCTAssertEqual(result.edition.allObligations.map(\.id), ["lab"],
                       "marking something handled must survive the next fetch")
    }

    func testSnoozeExpiresOnItsOwn() async {
        var memory = EditionMemory()
        memory.record(.snoozed(until: now.addingTimeInterval(-1)), for: "essay")

        let pipeline = EditionPipeline(sources: [
            FakeSource(kind: .quercus, outcome: .success([obligation("essay")]))
        ])
        let result = await pipeline.assemble(now: now, memory: memory)

        XCTAssertEqual(result.edition.allObligations.map(\.id), ["essay"],
                       "an elapsed snooze must bring the item back")
    }

    func testStateForVanishedObligationsIsForgotten() async {
        var memory = EditionMemory()
        memory.record(.handled(at: now), for: "old-course-assignment")
        memory.record(.handled(at: now), for: "still-here")

        let pipeline = EditionPipeline(sources: [
            FakeSource(kind: .quercus, outcome: .success([obligation("still-here")]))
        ])
        let result = await pipeline.assemble(now: now, memory: memory)

        XCTAssertNil(result.memory.states["old-course-assignment"],
                     "state for items no source reports must not accumulate forever")
        XCTAssertNotNil(result.memory.states["still-here"])
    }

    func testFailedSourceDoesNotWipeRememberedState() async {
        // A source that is merely unreachable must not look like a source reporting nothing,
        // or a transient outage would silently erase what the user had marked handled.
        var memory = EditionMemory()
        memory.record(.handled(at: now), for: "quercus-1")

        let pipeline = EditionPipeline(sources: [
            FakeSource(kind: .quercus, outcome: .success([obligation("quercus-1")])),
            FakeSource(kind: .schoolMail, outcome: .failure(.transport("offline")))
        ])
        let result = await pipeline.assemble(now: now, memory: memory)

        XCTAssertNotNil(result.memory.states["quercus-1"])
    }

    // MARK: - Ordering and concurrency

    func testOutputOrderIsStableRegardlessOfWhichSourceFinishesFirst() async {
        let slowFirst = EditionPipeline(sources: [
            FakeSource(kind: .quercus, outcome: .success([obligation("q")]), delay: .milliseconds(40)),
            FakeSource(kind: .personalMail, outcome: .success([obligation("m", source: .personalMail)]))
        ])
        let a = await slowFirst.assemble(now: now, memory: EditionMemory())
        let b = await slowFirst.assemble(now: now, memory: EditionMemory())

        XCTAssertEqual(a.edition.sources.map(\.kind), b.edition.sources.map(\.kind),
                       "the edition must not reshuffle because tasks finished in a different order")
    }

    func testSourcesRunConcurrentlyRatherThanInSequence() async {
        let sources: [any ObligationSource] = (0..<4).map { _ in
            FakeSource(kind: .quercus, outcome: .success([]), delay: .milliseconds(120))
        }
        let start = ContinuousClock.now
        _ = await EditionPipeline(sources: sources).assemble(now: now, memory: EditionMemory())
        let elapsed = ContinuousClock.now - start

        XCTAssertLessThan(elapsed, .milliseconds(400),
                          "four 120ms sources run in sequence would take about 480ms")
    }
}
