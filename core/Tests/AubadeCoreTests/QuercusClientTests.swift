import XCTest
@testable import AubadeCore

/// Serves canned replies and records what was asked for.
final class StubTransport: HTTPTransport, @unchecked Sendable {
    var replies: [HTTPReply]
    private(set) var requested: [URL] = []
    private(set) var sentHeaders: [[String: String]] = []

    init(replies: [HTTPReply]) { self.replies = replies }

    func get(_ url: URL, headers: [String: String]) async throws -> HTTPReply {
        requested.append(url)
        sentHeaders.append(headers)
        guard !replies.isEmpty else { throw SourceError.transport("no reply queued") }
        return replies.removeFirst()
    }
}

final class QuercusClientTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    func iso(_ offset: TimeInterval) -> String {
        ISO8601DateFormatter().string(from: now.addingTimeInterval(offset))
    }

    func reply(_ json: String, status: Int = 200, headers: [String: String] = [:]) -> HTTPReply {
        HTTPReply(status: status, body: Data(json.utf8), headers: headers)
    }

    func client(_ transport: HTTPTransport) -> QuercusClient {
        QuercusClient(token: "test-token", transport: transport)
    }

    func testParsesAssignmentAndSendsBearerToken() async throws {
        let json = "[{\"plannable_id\": 991, \"plannable_type\": \"assignment\","
            + "\"context_name\": \"CSC207H1\", \"html_url\": \"/courses/12/assignments/991\","
            + "\"plannable\": {\"title\": \"Problem Set 3\", \"due_at\": \"\(iso(3600))\"},"
            + "\"submissions\": {\"submitted\": false, \"excused\": false}}]"
        let stub = StubTransport(replies: [reply(json)])

        let result = try await client(stub).fetchObligations(now: now)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Problem Set 3")
        XCTAssertEqual(result[0].id, "quercus-991")
        XCTAssertEqual(result[0].source, .quercus)
        XCTAssertEqual(result[0].confidence, .stated)
        XCTAssertEqual(result[0].urgency(at: now), .dueSoon)
        XCTAssertEqual(
            result[0].sourceURL?.absoluteString,
            "https://q.utoronto.ca/courses/12/assignments/991"
        )
        XCTAssertEqual(stub.sentHeaders.first?["Authorization"], "Bearer test-token")
    }

    func testSubmissionsFalseDoesNotBreakDecoding() async throws {
        // Canvas sends `false` rather than an object for non-submittable items.
        let json = "[{\"plannable_id\": 5, \"plannable_type\": \"assignment\","
            + "\"context_name\": \"MAT137\","
            + "\"plannable\": {\"title\": \"Reading\", \"due_at\": \"\(iso(7200))\"},"
            + "\"submissions\": false}]"
        let result = try await client(StubTransport(replies: [reply(json)])).fetchObligations(now: now)
        XCTAssertEqual(result.count, 1, "a bare false must decode, not throw")
        XCTAssertEqual(result[0].confidence, .stated, "a future deadline is still a fact")
    }

    func testPastDueWithUnknownSubmissionIsACandidateNotAFact() async throws {
        // Never describe an item as overdue when Canvas will not confirm it is unsubmitted.
        let json = "[{\"plannable_id\": 7, \"plannable_type\": \"assignment\","
            + "\"context_name\": \"PSY100\","
            + "\"plannable\": {\"title\": \"Essay\", \"due_at\": \"\(iso(-86_400))\"},"
            + "\"submissions\": false}]"
        let result = try await client(StubTransport(replies: [reply(json)])).fetchObligations(now: now)

        XCTAssertEqual(result[0].confidence, .inferred)
        XCTAssertTrue(result[0].evidence.contains("may already be done"))

        let edition = EditionBuilder().build(obligations: result, sources: [], now: now)
        XCTAssertTrue(edition.allObligations.isEmpty, "a guess must never be asserted as an obligation")
        XCTAssertEqual(edition.candidates.count, 1)
    }

    func testSubmittedAndExcusedWorkIsDropped() async throws {
        let json = "[{\"plannable_id\": 1, \"plannable_type\": \"assignment\","
            + "\"plannable\": {\"title\": \"Done\", \"due_at\": \"\(iso(3600))\"},"
            + "\"submissions\": {\"submitted\": true, \"excused\": false}},"
            + "{\"plannable_id\": 2, \"plannable_type\": \"assignment\","
            + "\"plannable\": {\"title\": \"Excused\", \"due_at\": \"\(iso(3600))\"},"
            + "\"submissions\": {\"submitted\": false, \"excused\": true}}]"
        let result = try await client(StubTransport(replies: [reply(json)])).fetchObligations(now: now)
        XCTAssertTrue(result.isEmpty)
    }

    func testNonActionableTypesAreIgnored() async throws {
        let json = "[{\"plannable_id\": 3, \"plannable_type\": \"announcement\","
            + "\"plannable\": {\"title\": \"Class cancelled\"}, \"submissions\": false}]"
        let result = try await client(StubTransport(replies: [reply(json)])).fetchObligations(now: now)
        XCTAssertTrue(result.isEmpty, "an announcement is not an obligation")
    }

    func testRevokedTokenSurfacesAsUnauthorized() async {
        let stub = StubTransport(replies: [reply("{}", status: 401)])
        do {
            _ = try await client(stub).fetchObligations(now: now)
            XCTFail("expected unauthorized")
        } catch let error as SourceError {
            XCTAssertEqual(error, .unauthorized)
            XCTAssertEqual(error.userFacingReason, "access token rejected")
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testFollowsPaginationLinks() async throws {
        func page(_ id: Int) -> String {
            "[{\"plannable_id\": \(id), \"plannable_type\": \"assignment\","
                + "\"plannable\": {\"title\": \"Item \(id)\", \"due_at\": \"\(iso(3600))\"},"
                + "\"submissions\": {\"submitted\": false}}]"
        }
        let link = "<https://q.utoronto.ca/api/v1/planner/items?page=2>; rel=\"next\", "
            + "<https://q.utoronto.ca/api/v1/planner/items?page=9>; rel=\"last\""
        let stub = StubTransport(replies: [
            reply(page(1), headers: ["Link": link]),
            reply(page(2))
        ])

        let result = try await client(stub).fetchObligations(now: now)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(stub.requested.count, 2)
        XCTAssertEqual(
            stub.requested[1].absoluteString,
            "https://q.utoronto.ca/api/v1/planner/items?page=2"
        )
    }

    func testPaginationIsBounded() async throws {
        let body = "[{\"plannable_id\": 1, \"plannable_type\": \"assignment\","
            + "\"plannable\": {\"title\": \"Loop\", \"due_at\": \"\(iso(3600))\"},"
            + "\"submissions\": false}]"
        let alwaysNext = "<https://q.utoronto.ca/api/v1/planner/items?page=2>; rel=\"next\""
        let stub = StubTransport(
            replies: Array(repeating: reply(body, headers: ["Link": alwaysNext]), count: 50)
        )

        _ = try await QuercusClient(token: "t", transport: stub, maxPages: 3)
            .fetchObligations(now: now)

        XCTAssertEqual(
            stub.requested.count, 3,
            "a server that always advertises another page must not hang the morning"
        )
    }

    func testMalformedBodyIsReportedNotCrashed() async {
        let stub = StubTransport(replies: [reply("not json at all")])
        do {
            _ = try await client(stub).fetchObligations(now: now)
            XCTFail("expected failure")
        } catch let error as SourceError {
            guard case .malformedResponse = error else { return XCTFail("wrong case: \(error)") }
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
