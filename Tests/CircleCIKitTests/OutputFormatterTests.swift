import XCTest
@testable import CircleCIKit

final class OutputFormatterTests: XCTestCase {

    private func jobs() throws -> [Job] {
        try CircleCIJSON.decoder.decode(Paged<Job>.self, from: Data(Fixtures.jobsPage.utf8)).items
    }

    func testIDFormat() throws {
        let output = try OutputFormatter.render(jobs(), format: .id)
        let lines = output.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines, [
            "58ae7914-6179-4a77-8b30-d324afaf048f",
            "9ae3058a-78b7-492a-a3f9-579fa466df15",
            "bc4fa18b-bcad-4c6f-936a-01938e16583e"
        ])
    }

    func testTableFormatHasHeaderAndRows() throws {
        let output = try OutputFormatter.render(jobs(), format: .table)
        let lines = output.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 2 + 3) // header + separator + 3 rows
        XCTAssertTrue(lines[0].contains("NAME"))
        XCTAssertTrue(lines[0].contains("TYPE"))
        XCTAssertTrue(lines[0].contains("STATUS"))
        XCTAssertTrue(lines.contains { $0.contains("approve-mac-release") && $0.contains("approval") })
    }

    func testTableNoTrailingWhitespaceInLastColumn() {
        let table = OutputFormatter.renderTable(columns: ["A", "B"], rows: [["x", "y"], ["longer", "z"]])
        for line in table.split(separator: "\n") {
            XCTAssertFalse(line.hasSuffix(" "), "table line should not end in whitespace: '\(line)'")
        }
    }

    func testJSONLFormatOneObjectPerLine() throws {
        let output = try OutputFormatter.render(jobs(), format: .jsonl)
        let lines = output.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 3)
        for line in lines {
            let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
            XCTAssertNotNil(object?["id"])
        }
    }

    func testJSONFormatIsAnArray() throws {
        let output = try OutputFormatter.render(jobs(), format: .json)
        let array = try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]]
        XCTAssertEqual(array?.count, 3)
    }

    func testEmptyListRendersEmptyForIDAndJSONL() throws {
        let empty: [Job] = []
        XCTAssertEqual(try OutputFormatter.render(empty, format: .id), "")
        XCTAssertEqual(try OutputFormatter.render(empty, format: .jsonl), "")
        XCTAssertEqual(try OutputFormatter.render(empty, format: .json), "[]")
    }
}
