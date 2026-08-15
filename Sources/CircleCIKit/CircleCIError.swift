//
//  CircleCIError.swift
//  cirqueduci
//
//  Mirrors hunch's NotionAPIServiceError: a typed error covering the failure
//  modes of talking to the CircleCI v2 API, with a decoding-detail helper that
//  surfaces the failing coding path instead of an opaque message.
//

import Foundation

public enum CircleCIError: Error, LocalizedError {
    case missingToken
    case apiError(_ error: Error)
    case invalidEndpoint
    case invalidResponse
    case invalidResponseStatus(_ status: Int, message: String?)
    case noData
    case decodeError(_ error: Error, context: String? = nil)
    case encodeError(_ error: Error)
    case rateLimitExceeded(retryAfter: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            return "missing token: set CIRCLECI_API_KEY (or CIRCLECI_TOKEN) in the environment or a .env file"
        case .apiError(let error):
            return "api error: \(error.localizedDescription)"
        case .invalidEndpoint:
            return "invalid endpoint"
        case .invalidResponse:
            return "invalid response"
        case .invalidResponseStatus(let statusCode, let message):
            if let message = message, !message.isEmpty {
                return "invalid response status: \(statusCode) — \(message)"
            }
            return "invalid response status: \(statusCode)"
        case .noData:
            return "no data"
        case .decodeError(let error, let context):
            var message = "decode error"
            if let context = context {
                message += " (\(context))"
            }
            message += ": \(CircleCIError.decodingDetail(error))"
            return message
        case .encodeError(let error):
            return "encode error: \(error.localizedDescription)"
        case .rateLimitExceeded(let retryAfter):
            return "Rate limit exceeded. Retry after \(retryAfter) seconds"
        }
    }

    /// Extracts the coding path and underlying reason from a `DecodingError`
    /// so callers can see which field failed and why, rather than the opaque
    /// "isn't in the correct format" that `localizedDescription` produces.
    static func decodingDetail(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        func path(_ context: DecodingError.Context) -> String {
            let components = context.codingPath.map { key -> String in
                if let index = key.intValue {
                    return "[\(index)]"
                }
                return key.stringValue
            }
            return components.isEmpty ? "<root>" : components.joined(separator: ".")
        }

        switch decodingError {
        case .dataCorrupted(let context):
            return "at \(path(context)): \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "at \(path(context)): missing key \"\(key.stringValue)\""
        case .typeMismatch(let type, let context):
            return "at \(path(context)): type mismatch for \(type): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "at \(path(context)): missing value for \(type): \(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }
}
