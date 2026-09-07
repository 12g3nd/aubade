import Foundation

/// Reads coursework from Quercus (UofT's Canvas) using a personal access token the
/// user generates at Account > Settings and can revoke at any time.
///
/// Read-only by construction: this client only ever issues GETs.
public struct QuercusClient: Sendable {
    public static let defaultBaseURL = URL(string: "https://q.utoronto.ca")!

    private let baseURL: URL
    private let token: String
    private let transport: HTTPTransport
    /// Bound so a runaway pagination loop cannot hang the morning.
    private let maxPages: Int

    public init(
        baseURL: URL = QuercusClient.defaultBaseURL,
        token: String,
        transport: HTTPTransport,
        maxPages: Int = 10
    ) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
        self.maxPages = maxPages
    }

    /// Fetches planner items in the window the edition cares about: anything still
    /// overdue behind us, and far enough ahead to spot work worth starting.
    public func fetchObligations(
        now: Date,
        lookBackDays: Int = 14,
        lookAheadDays: Int = 14
    ) async throws -> [Obligation] {
        let start = now.addingTimeInterval(-Double(lookBackDays) * 86_400)
        let end = now.addingTimeInterval(Double(lookAheadDays) * 86_400)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/v1/planner/items"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: formatter.string(from: start)),
            URLQueryItem(name: "end_date", value: formatter.string(from: end)),
            URLQueryItem(name: "per_page", value: "100")
        ]

        var next: URL? = components.url
        var pages = 0
        var items: [PlannerItem] = []

        while let url = next, pages < maxPages {
            let reply = try await transport.get(url, headers: [
                "Authorization": "Bearer \(token)",
                "Accept": "application/json"
            ])
            switch reply.status {
            case 200: break
            case 401, 403: throw SourceError.unauthorized
            default: throw SourceError.http(status: reply.status)
            }
            do {
                items += try JSONDecoder().decode([PlannerItem].self, from: reply.body)
            } catch {
                throw SourceError.malformedResponse("\(error)")
            }
            next = reply.nextLink
            pages += 1
        }

        return items.compactMap { $0.asObligation(now: now, baseURL: baseURL) }
    }
}

// MARK: - Canvas payload

/// A planner item as Canvas returns it. Only the fields we actually rely on.
struct PlannerItem: Decodable {
    let plannableID: Int
    let plannableType: String
    let contextName: String?
    let htmlURL: String?
    let plannable: Plannable
    let submissions: SubmissionStatus

    enum CodingKeys: String, CodingKey {
        case plannableID = "plannable_id"
        case plannableType = "plannable_type"
        case contextName = "context_name"
        case htmlURL = "html_url"
        case plannable, submissions
    }

    struct Plannable: Decodable {
        let title: String?
        let dueAt: Date?

        enum CodingKeys: String, CodingKey {
            case title
            case dueAt = "due_at"
            case todoDate = "todo_date"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decodeIfPresent(String.self, forKey: .title)
            let raw = try c.decodeIfPresent(String.self, forKey: .dueAt)
                ?? c.decodeIfPresent(String.self, forKey: .todoDate)
            dueAt = raw.flatMap(PlannerItem.parseDate)
        }
    }

    /// Canvas sends an object for submittable things and the bare value `false` for
    /// everything else. Decoding it as an object throws on perfectly normal payloads,
    /// so the absent case is modelled explicitly rather than treated as an error.
    enum SubmissionStatus: Decodable {
        case unknown
        case known(submitted: Bool, excused: Bool)

        struct Fields: Decodable {
            let submitted: Bool?
            let excused: Bool?
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let fields = try? container.decode(Fields.self) {
                self = .known(submitted: fields.submitted ?? false, excused: fields.excused ?? false)
            } else {
                self = .unknown
            }
        }

        var isFinished: Bool {
            if case .known(let submitted, let excused) = self { return submitted || excused }
            return false
        }

        var isConfirmedOutstanding: Bool {
            if case .known(let submitted, let excused) = self { return !submitted && !excused }
            return false
        }
    }

    static func parseDate(_ raw: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFractional.date(from: raw) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }

    /// Types that can actually place an obligation on the user.
    static let actionableTypes: Set<String> = [
        "assignment", "quiz", "discussion_topic", "sub_assignment", "planner_note"
    ]

    func asObligation(now: Date, baseURL: URL) -> Obligation? {
        guard PlannerItem.actionableTypes.contains(plannableType) else { return nil }
        guard !submissions.isFinished else { return nil }
        guard let title = plannable.title, !title.isEmpty else { return nil }

        let due = plannable.dueAt
        let course = contextName ?? "Quercus"

        // Q22: a missing submission status must not be reported as overdue. When Canvas
        // will not tell us whether it was handed in, an item whose deadline has passed
        // is a candidate to check, not a fact to assert.
        let pastDue = due.map { $0 < now } ?? false
        let confidence: Confidence
        let evidence: String
        if submissions.isConfirmedOutstanding {
            confidence = .stated
            evidence = "\(course) - Quercus shows this as not submitted"
        } else if pastDue {
            confidence = .inferred
            evidence = "\(course) - deadline passed; Quercus does not report a submission status, so this may already be done"
        } else {
            confidence = .stated
            evidence = "\(course) - due date from Quercus"
        }

        return Obligation(
            id: "quercus-\(plannableID)",
            title: title,
            source: .quercus,
            dueAt: due,
            sourceURL: htmlURL.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL },
            evidence: evidence,
            confidence: confidence
        )
    }
}
