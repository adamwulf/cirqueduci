//
//  CircleCIJSON.swift
//  cirqueduci
//
//  Shared JSONDecoder/JSONEncoder configured for CircleCI's ISO-8601 timestamps
//  (e.g. "2026-08-14T23:40:50.978Z"). Exposed so the API client AND the unit
//  tests decode canned JSON with identical settings — mirroring how hunch's
//  ModelTests reuse the same date strategy as NotionAPI.
//

import Foundation

public enum CircleCIJSON {

    /// Decoder configured to parse CircleCI timestamps, tolerant of both
    /// fractional-second and whole-second ISO-8601 forms.
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = CircleCIDate.parse(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(string)"
            )
        }
        return decoder
    }()

    /// Encoder that writes CircleCI-style fractional-second ISO-8601 timestamps.
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(CircleCIDate.string(from: date))
        }
        return encoder
    }()
}

/// Parses/formats the ISO-8601 timestamps CircleCI returns.
enum CircleCIDate {
    private static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        withFractional.date(from: string) ?? withoutFractional.date(from: string)
    }

    static func string(from date: Date) -> String {
        withFractional.string(from: date)
    }
}
