import XCTest
@testable import CircleCIKit

final class DotEnvTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DotEnvTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - parseValue(forKey:in:)

    func testBasicKeyValue() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "CIRCLECI_API_KEY=cci_abc123".write(to: envFile, atomically: true, encoding: .utf8)
        XCTAssertEqual(DotEnv.parseValue(forKey: "CIRCLECI_API_KEY", in: envFile), "cci_abc123")
    }

    func testDoubleQuotedValue() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "CIRCLECI_API_KEY=\"cci_abc123\"".write(to: envFile, atomically: true, encoding: .utf8)
        XCTAssertEqual(DotEnv.parseValue(forKey: "CIRCLECI_API_KEY", in: envFile), "cci_abc123")
    }

    func testSingleQuotedValue() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "CIRCLECI_API_KEY='cci_abc123'".write(to: envFile, atomically: true, encoding: .utf8)
        XCTAssertEqual(DotEnv.parseValue(forKey: "CIRCLECI_API_KEY", in: envFile), "cci_abc123")
    }

    func testSkipsCommentsAndBlankLines() {
        let contents = """
        # a comment

        CIRCLECI_API_KEY=cci_abc123

        """
        let envFile = tempDir.appendingPathComponent(".env")
        try! contents.write(to: envFile, atomically: true, encoding: .utf8)
        XCTAssertEqual(DotEnv.parseValue(forKey: "CIRCLECI_API_KEY", in: envFile), "cci_abc123")
    }

    func testReturnsNilForMissingKey() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "OTHER=value".write(to: envFile, atomically: true, encoding: .utf8)
        XCTAssertNil(DotEnv.parseValue(forKey: "CIRCLECI_API_KEY", in: envFile))
    }

    func testReturnsNilForEmptyValue() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "CIRCLECI_API_KEY=".write(to: envFile, atomically: true, encoding: .utf8)
        XCTAssertNil(DotEnv.parseValue(forKey: "CIRCLECI_API_KEY", in: envFile))
    }

    func testDoesNotMatchKeyPrefix() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "CIRCLECI_API_KEY_EXTRA=wrong".write(to: envFile, atomically: true, encoding: .utf8)
        XCTAssertNil(DotEnv.parseValue(forKey: "CIRCLECI_API_KEY", in: envFile))
    }

    func testTrimsWhitespaceAroundValue() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "CIRCLECI_API_KEY=  cci_abc123  ".write(to: envFile, atomically: true, encoding: .utf8)
        XCTAssertEqual(DotEnv.parseValue(forKey: "CIRCLECI_API_KEY", in: envFile), "cci_abc123")
    }

    // MARK: - loadValue(forKey:startingIn:)

    func testWalksUpDirectories() {
        let nested = tempDir.appendingPathComponent("a/b/c")
        try! FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let envFile = tempDir.appendingPathComponent(".env")
        try! "CIRCLECI_API_KEY=cci_found_it".write(to: envFile, atomically: true, encoding: .utf8)
        XCTAssertEqual(DotEnv.loadValue(forKey: "CIRCLECI_API_KEY", startingIn: nested), "cci_found_it")
    }

    func testClosestEnvFileWins() {
        let child = tempDir.appendingPathComponent("child")
        try! FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try! "CIRCLECI_API_KEY=parent".write(to: tempDir.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        try! "CIRCLECI_API_KEY=child".write(to: child.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        XCTAssertEqual(DotEnv.loadValue(forKey: "CIRCLECI_API_KEY", startingIn: child), "child")
    }
}
