//
//  Responses.swift
//  cirqueduci
//
//  Small response bodies for write operations and generic messages.
//

import Foundation

/// The response from POST /project/{slug}/pipeline (trigger).
public struct TriggerPipelineResponse: Codable, Identifiable {
    public let id: String
    public let number: Int?
    public let state: PipelineState?
    public let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case number
        case state
        case createdAt = "created_at"
    }
}

/// A generic `{ "message": "…" }` body (e.g. the approve/cancel/rerun endpoints).
public struct MessageResponse: Codable {
    public let message: String?
}

/// The body posted to trigger a pipeline: a branch OR a tag, plus optional
/// pipeline parameters. Parameters accept string/number/bool values.
public struct TriggerPipelineRequest: Codable {
    public let branch: String?
    public let tag: String?
    public let parameters: [String: ParameterValue]?

    public init(branch: String? = nil, tag: String? = nil, parameters: [String: ParameterValue]? = nil) {
        self.branch = branch
        self.tag = tag
        self.parameters = parameters
    }
}

/// A CircleCI pipeline parameter value: string, integer, or boolean.
public enum ParameterValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }

    /// Infers a value's type from a raw string: `true`/`false` → bool, an
    /// integer literal → int, otherwise string.
    public static func parse(_ raw: String) -> ParameterValue {
        if raw == "true" { return .bool(true) }
        if raw == "false" { return .bool(false) }
        if let intValue = Int(raw) { return .int(intValue) }
        return .string(raw)
    }

    /// Parses a `key=value` pair into (key, ParameterValue). Returns nil when
    /// there is no `=`.
    public static func parsePair(_ raw: String) -> (String, ParameterValue)? {
        guard let separator = raw.firstIndex(of: "=") else { return nil }
        let key = String(raw[raw.startIndex..<separator])
        let value = String(raw[raw.index(after: separator)...])
        guard !key.isEmpty else { return nil }
        return (key, parse(value))
    }
}
