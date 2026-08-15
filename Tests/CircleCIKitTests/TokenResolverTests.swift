import XCTest
@testable import CircleCIKit

final class TokenResolverTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenResolverTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testPrimaryKeyPreferred() {
        let env = ["CIRCLECI_API_KEY": "primary", "CIRCLECI_TOKEN": "fallback"]
        XCTAssertEqual(TokenResolver.fromEnvironment(env), "primary")
    }

    func testFallbackKeyUsedWhenPrimaryMissing() {
        let env = ["CIRCLECI_TOKEN": "fallback"]
        XCTAssertEqual(TokenResolver.fromEnvironment(env), "fallback")
    }

    func testEmptyValuesIgnored() {
        let env = ["CIRCLECI_API_KEY": "", "CIRCLECI_TOKEN": "fallback"]
        XCTAssertEqual(TokenResolver.fromEnvironment(env), "fallback")
    }

    func testNoTokenReturnsNil() {
        XCTAssertNil(TokenResolver.fromEnvironment([:]))
    }

    func testDotEnvPrimaryKey() {
        try! "CIRCLECI_API_KEY=from_dotenv".write(to: tempDir.appendingPathComponent(".env"),
                                                  atomically: true, encoding: .utf8)
        XCTAssertEqual(TokenResolver.fromDotEnv(startingIn: tempDir), "from_dotenv")
    }

    func testDotEnvFallbackKey() {
        try! "CIRCLECI_TOKEN=from_dotenv_fallback".write(to: tempDir.appendingPathComponent(".env"),
                                                         atomically: true, encoding: .utf8)
        XCTAssertEqual(TokenResolver.fromDotEnv(startingIn: tempDir), "from_dotenv_fallback")
    }

    func testResolvePrefersEnvironmentOverDotEnv() {
        try! "CIRCLECI_API_KEY=from_dotenv".write(to: tempDir.appendingPathComponent(".env"),
                                                  atomically: true, encoding: .utf8)
        let env = ["CIRCLECI_API_KEY": "from_env"]
        XCTAssertEqual(TokenResolver.resolve(environment: env, startingIn: tempDir), "from_env")
    }

    func testResolveFallsBackToDotEnv() {
        try! "CIRCLECI_API_KEY=from_dotenv".write(to: tempDir.appendingPathComponent(".env"),
                                                  atomically: true, encoding: .utf8)
        XCTAssertEqual(TokenResolver.resolve(environment: [:], startingIn: tempDir), "from_dotenv")
    }
}
