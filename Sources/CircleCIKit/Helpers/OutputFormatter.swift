//
//  OutputFormatter.swift
//  cirqueduci
//
//  Formatting lives in the library (reusable + testable); the thin CLI only
//  picks a format. Mirrors hunch's Renderer split, generalized over any model
//  that describes its own table columns / id.
//

import Foundation

/// A model that knows how to present itself as a table row and an id.
public protocol CircleCIRow: Encodable {
    /// Column headers for `--format table`.
    static var tableColumns: [String] { get }
    /// One value per column, in the same order as `tableColumns`.
    var tableValues: [String] { get }
    /// The value emitted by `--format id`.
    var idValue: String { get }
}

public enum OutputFormat: String, CaseIterable {
    case table
    case json
    case jsonl
    case id
}

public enum OutputFormatter {

    /// Renders a homogeneous list of rows in the requested format.
    public static func render<T: CircleCIRow>(_ items: [T], format: OutputFormat) throws -> String {
        switch format {
        case .id:
            return items.map { $0.idValue }.joined(separator: "\n")
        case .table:
            return renderTable(columns: T.tableColumns, rows: items.map { $0.tableValues })
        case .jsonl:
            return try items.map { try jsonLine($0) }.joined(separator: "\n")
        case .json:
            return try jsonArray(items)
        }
    }

    // MARK: - JSON

    private static func jsonLine<T: Encodable>(_ item: T) throws -> String {
        let data = try CircleCIJSON.encoder.encode(item)
        let object = try JSONSerialization.jsonObject(with: data)
        let line = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(data: line, encoding: .utf8) ?? ""
    }

    private static func jsonArray<T: Encodable>(_ items: [T]) throws -> String {
        if items.isEmpty { return "[]" }
        let objects: [Any] = try items.map { item in
            let data = try CircleCIJSON.encoder.encode(item)
            return try JSONSerialization.jsonObject(with: data)
        }
        let data = try JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    // MARK: - Table

    /// Renders a monospaced, column-aligned table with a header row.
    public static func renderTable(columns: [String], rows: [[String]]) -> String {
        guard !columns.isEmpty else { return "" }
        var widths = columns.map { $0.count }
        for row in rows {
            for (index, value) in row.enumerated() where index < widths.count {
                widths[index] = max(widths[index], value.count)
            }
        }

        func format(_ values: [String]) -> String {
            values.enumerated().map { index, value -> String in
                guard index < widths.count else { return value }
                // Do not pad the final column (avoids trailing whitespace).
                if index == widths.count - 1 { return value }
                return value.padding(toLength: widths[index], withPad: " ", startingAt: 0)
            }.joined(separator: "  ")
        }

        var lines = [format(columns)]
        lines.append(widths.map { String(repeating: "-", count: $0) }.joined(separator: "  "))
        for row in rows {
            lines.append(format(row))
        }
        return lines.joined(separator: "\n")
    }
}
