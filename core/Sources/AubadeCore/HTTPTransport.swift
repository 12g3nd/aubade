import Foundation

/// The one place the core talks to the network.
///
/// Kept behind a protocol so every client above it can be tested against canned
/// responses. Nothing in the core reaches for URLSession directly.
public protocol HTTPTransport: Sendable {
    func get(_ url: URL, headers: [String: String]) async throws -> HTTPReply
}

public struct HTTPReply: Sendable {
    public let status: Int
    public let body: Data
    public let headers: [String: String]

    public init(status: Int, body: Data, headers: [String: String] = [:]) {
        self.status = status
        self.body = body
        self.headers = headers
    }

    /// Canvas paginates with RFC 5988 Link headers. Returns the `next` page if there is one.
    public var nextLink: URL? {
        let raw = headers.first { $0.key.lowercased() == "link" }?.value
        guard let raw else { return nil }
        for part in raw.split(separator: ",") {
            let segments = part.split(separator: ";")
            guard segments.count >= 2 else { continue }
            let relIsNext = segments.dropFirst().contains {
                $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "") == "rel=next"
            }
            guard relIsNext else { continue }
            let urlPart = segments[0].trimmingCharacters(in: .whitespaces)
            guard urlPart.hasPrefix("<"), urlPart.hasSuffix(">") else { continue }
            return URL(string: String(urlPart.dropFirst().dropLast()))
        }
        return nil
    }
}

public enum SourceError: Error, Equatable, Sendable {
    /// The token is missing, wrong, or has been revoked. Distinguished from other
    /// failures because it is the one the user can actually fix.
    case unauthorized
    case http(status: Int)
    case malformedResponse(String)
    case transport(String)

    public var userFacingReason: String {
        switch self {
        case .unauthorized: return "access token rejected"
        case .http(let status): return "server returned \(status)"
        case .malformedResponse: return "unexpected response format"
        case .transport(let detail): return detail
        }
    }
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL, headers: [String: String]) async throws -> HTTPReply {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw SourceError.malformedResponse("not an HTTP response")
            }
            var headerMap: [String: String] = [:]
            for (key, value) in http.allHeaderFields {
                if let k = key as? String, let v = value as? String { headerMap[k] = v }
            }
            return HTTPReply(status: http.statusCode, body: data, headers: headerMap)
        } catch let error as SourceError {
            throw error
        } catch {
            throw SourceError.transport(error.localizedDescription)
        }
    }
}
