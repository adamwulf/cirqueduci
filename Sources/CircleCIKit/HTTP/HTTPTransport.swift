//
//  HTTPTransport.swift
//  cirqueduci
//
//  Abstracts the HTTP layer so the API client can be unit-tested with canned
//  responses and no live network. The real implementation wraps URLSession;
//  tests inject a stub that returns fixed JSON keyed by request.
//

import Foundation

/// A single HTTP request as issued by the API client. Kept transport-agnostic
/// so a stub can match on `method`/`url` without touching URLSession.
public struct HTTPRequest: Sendable, Equatable {
    public let method: String
    public let url: URL
    public let headers: [String: String]
    public let body: Data?

    public init(method: String, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

/// A minimal HTTP response: status code, headers, and the raw body bytes.
public struct HTTPResponse: Sendable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

/// The seam the API client talks to. Production uses `URLSessionTransport`;
/// tests inject a stub conforming to this protocol.
public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

/// The real transport, backed by `URLSession`.
public final class URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = request.body

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw CircleCIError.invalidResponse
        }

        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        return HTTPResponse(status: http.statusCode, headers: headers, body: data)
    }
}
