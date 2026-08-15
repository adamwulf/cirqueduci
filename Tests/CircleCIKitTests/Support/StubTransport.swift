//
//  StubTransport.swift
//  cirqueduci
//
//  The test double for HTTPTransport: returns canned JSON with no live network.
//  This is the seam hunch lacks — it lets us unit-test the API client's URL
//  building, header handling, pagination, and decoding entirely offline.
//

import Foundation
@testable import CircleCIKit

/// A canned reply for a matched request.
struct StubReply {
    var status: Int = 200
    var headers: [String: String] = [:]
    var body: Data

    init(status: Int = 200, headers: [String: String] = [:], body: Data) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    init(status: Int = 200, headers: [String: String] = [:], json: String) {
        self.init(status: status, headers: headers, body: Data(json.utf8))
    }
}

/// An HTTPTransport that answers from a list of matchers. Each request is
/// matched (by predicate) to the FIRST reply whose matcher fires; a stub that
/// receives an unmatched request records it and returns a 599 so tests fail
/// loudly rather than silently hitting the network.
final class StubTransport: HTTPTransport, @unchecked Sendable {

    struct Matcher {
        let matches: (HTTPRequest) -> Bool
        let reply: (HTTPRequest) -> StubReply
    }

    private(set) var requests: [HTTPRequest] = []
    private var matchers: [Matcher] = []

    init() {}

    /// Convenience: reply with `json` when the request URL contains `pathFragment`
    /// (and, optionally, uses `method`).
    @discardableResult
    func on(_ pathFragment: String, method: String? = nil, status: Int = 200, json: String) -> StubTransport {
        matchers.append(Matcher(
            matches: { request in
                if let method = method, request.method != method { return false }
                return request.url.absoluteString.contains(pathFragment)
            },
            reply: { _ in StubReply(status: status, json: json) }
        ))
        return self
    }

    /// Match with a custom predicate + reply builder (e.g. paginated responses
    /// keyed by the page-token query item).
    @discardableResult
    func on(where predicate: @escaping (HTTPRequest) -> Bool, reply: @escaping (HTTPRequest) -> StubReply) -> StubTransport {
        matchers.append(Matcher(matches: predicate, reply: reply))
        return self
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        for matcher in matchers where matcher.matches(request) {
            let reply = matcher.reply(request)
            return HTTPResponse(status: reply.status, headers: reply.headers, body: reply.body)
        }
        return HTTPResponse(status: 599,
                            headers: [:],
                            body: Data("no stub matched \(request.method) \(request.url.absoluteString)".utf8))
    }
}
