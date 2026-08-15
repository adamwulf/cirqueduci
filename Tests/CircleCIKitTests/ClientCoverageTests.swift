import XCTest
@testable import CircleCIKit

/// Coverage for paths not exercised by APITests: retry/backoff, rate-limit
/// exhaustion, the watch poll loop, artifact download (incl. its path-traversal
/// guard), and the remaining endpoints driven through the client + StubTransport.
final class ClientCoverageTests: XCTestCase {

    /// No real sleeping in retry tests.
    private func makeAPI(_ stub: StubTransport, token: String? = "test-token") -> CircleCIAPI {
        CircleCIAPI(transport: stub, token: token, minRetryDelay: 0, maxRetryDelay: 0)
    }

    private func makeClient(_ stub: StubTransport, token: String? = "test-token") -> CircleCIClient {
        CircleCIClient(api: makeAPI(stub, token: token))
    }

    // MARK: - Retry / backoff

    func testRetriesOn500ThenSucceeds() async throws {
        let stub = StubTransport().onSequence("/me", replies: [
            StubReply(status: 500, json: "{\"message\":\"server error\"}"),
            StubReply(status: 200, json: Fixtures.me)
        ])
        let api = makeAPI(stub)
        let result = await api.me()
        guard case .success(let me) = result else { return XCTFail("expected success, got \(result)") }
        XCTAssertEqual(me.login, "adamwulf")
        XCTAssertEqual(stub.requests.count, 2, "one retry after the 500")
    }

    func testRateLimitExhaustionReturnsRateLimitError() async {
        let stub = StubTransport().on("/me", status: 429, json: "{\"message\":\"rate limited\"}")
        let api = makeAPI(stub)
        let result = await api.me()
        if case .failure(let error) = result, case .rateLimitExceeded = error {
            // expected
        } else {
            XCTFail("expected .rateLimitExceeded, got \(result)")
        }
        XCTAssertEqual(stub.requests.count, 4, "initial + 3 retries")
    }

    // MARK: - Watch poll loop

    func testWaitForPipelinePollsUntilFinished() async throws {
        let successWorkflows = """
        { "items": [ { "id": "wf-1", "name": "release-deploy", "status": "success",
          "pipeline_id": "p1", "created_at": "2026-08-14T23:40:51.361Z", "stopped_at": "2026-08-14T23:55:00.000Z" } ],
          "next_page_token": null }
        """
        let stub = StubTransport().onSequence("/workflow", replies: [
            StubReply(json: Fixtures.workflowsPage), // on_hold
            StubReply(json: successWorkflows)         // success
        ])
        let client = makeClient(stub)

        var pollCount = 0
        let finalWorkflows = try await client.waitForPipeline(id: "p1", pollInterval: 0, timeout: 5) { _ in
            pollCount += 1
        }
        XCTAssertEqual(pollCount, 2)
        XCTAssertTrue(CircleCIClient.allFinished(finalWorkflows))
        XCTAssertFalse(CircleCIClient.anyFailed(finalWorkflows))
    }

    func testWaitForPipelineTimesOutWhileRunning() async throws {
        // Always on_hold; a 0 timeout returns after the first poll without finishing.
        let stub = StubTransport().on("/workflow", json: Fixtures.workflowsPage)
        let client = makeClient(stub)
        let workflows = try await client.waitForPipeline(id: "p1", pollInterval: 0, timeout: 0)
        XCTAssertFalse(CircleCIClient.allFinished(workflows))
    }

    func testAnyFailedDetectsFailure() throws {
        let failed = """
        { "id": "wf", "name": "n", "status": "failed", "created_at": "2026-08-14T23:40:51.361Z" }
        """
        let workflow = try CircleCIJSON.decoder.decode(Workflow.self, from: Data(failed.utf8))
        XCTAssertTrue(CircleCIClient.anyFailed([workflow]))
    }

    // MARK: - Artifact download + traversal guard

    func testDownloadArtifactsWritesFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("artifacts-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stub = StubTransport()
            .on("/artifacts", json: Fixtures.artifactsPage)
            .on("output.circle-artifacts.com", json: "BINARY-CONTENT")
        let client = makeClient(stub)

        let downloaded = try await client.downloadArtifacts(projectSlug: "gh/museapphq/Muse",
                                                            jobNumber: 40796, to: tempDir)
        XCTAssertEqual(downloaded.count, 2)
        let resultsFile = tempDir.appendingPathComponent("test-results/results.xml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: resultsFile.path))
        XCTAssertEqual(try String(contentsOf: resultsFile, encoding: .utf8), "BINARY-CONTENT")
    }

    func testDownloadArtifactsSanitizesTraversalPaths() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("artifacts-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let evilArtifacts = """
        { "items": [
          { "path": "/../../etc/evil.txt", "node_index": 0,
            "url": "https://output.circle-artifacts.com/abc/evil.txt" }
        ], "next_page_token": null }
        """
        let stub = StubTransport()
            .on("/artifacts", json: evilArtifacts)
            .on("output.circle-artifacts.com", json: "PWNED")
        let client = makeClient(stub)

        let downloaded = try await client.downloadArtifacts(projectSlug: "gh/museapphq/Muse",
                                                            jobNumber: 1, to: tempDir)
        XCTAssertEqual(downloaded.count, 1)
        // The written file must stay INSIDE the target directory.
        let destination = downloaded[0].localURL.standardizedFileURL.path
        XCTAssertTrue(destination.hasPrefix(tempDir.standardizedFileURL.path),
                      "artifact escaped the target directory: \(destination)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: "/etc/evil.txt"))
    }

    // MARK: - Remaining endpoints through the client

    func testFollowedProjectsThroughClient() async throws {
        let stub = StubTransport().on("/api/v1.1/projects", json: Fixtures.followedProjects)
        let client = makeClient(stub)
        let projects = try await client.followedProjects()
        XCTAssertEqual(projects.first?.slug, "gh/museapphq/Muse")
        XCTAssertTrue(stub.requests.first?.url.absoluteString.hasSuffix("/api/v1.1/projects") ?? false)
    }

    func testCollaborationsThroughClient() async throws {
        let stub = StubTransport().on("/me/collaborations", json: Fixtures.collaborations)
        let client = makeClient(stub)
        let collaborations = try await client.collaborations()
        XCTAssertEqual(collaborations.first?.slug, "gh/museapphq")
    }

    func testProjectThroughClient() async throws {
        let stub = StubTransport().on("/project/", json: Fixtures.project)
        let client = makeClient(stub)
        let project = try await client.project(slug: "gh/museapphq/Muse")
        XCTAssertEqual(project.name, "Muse")
    }

    func testJobDetailThroughClient() async throws {
        let stub = StubTransport().on("/job/", json: Fixtures.jobDetail)
        let client = makeClient(stub)
        let detail = try await client.jobDetail(projectSlug: "gh/museapphq/Muse", jobNumber: 40796)
        XCTAssertEqual(detail.number, 40796)
        XCTAssertEqual(detail.status, .success)
    }

    func testTestsThroughClient() async throws {
        let stub = StubTransport().on("/tests", json: Fixtures.testsPage)
        let client = makeClient(stub)
        let results = try await client.tests(projectSlug: "gh/museapphq/Muse", jobNumber: 40796)
        XCTAssertEqual(results.first?.classname, "FooTests")
    }

    func testCancelAndRerunThroughClient() async throws {
        let cancelStub = StubTransport().on("/cancel", method: "POST", json: Fixtures.approveAccepted)
        let cancel = try await makeClient(cancelStub).cancelWorkflow(id: "wf-1")
        XCTAssertEqual(cancel.message, "Accepted.")
        XCTAssertEqual(cancelStub.requests.first?.method, "POST")

        let rerunStub = StubTransport().on("/rerun", method: "POST", json: "{\"message\":\"Rerunning.\"}")
        let rerun = try await makeClient(rerunStub).rerunWorkflow(id: "wf-1")
        XCTAssertEqual(rerun.message, "Rerunning.")
    }

    // MARK: - Security / correctness fixes

    func testTokenNotSentToLookalikeHost() async throws {
        // A host that merely ends in "circleci.com" (evilcircleci.com) must NOT
        // receive the Circle-Token.
        let stub = StubTransport().on("evilcircleci.com", json: "{}")
        let api = makeAPI(stub)
        let url = try XCTUnwrap(URL(string: "https://evilcircleci.com/steal"))
        _ = await api.downloadData(from: url)
        XCTAssertNil(stub.requests.first?.headers["Circle-Token"])
    }

    func testTokenSentToArtifactSubdomain() async throws {
        let stub = StubTransport().on("output.circle-artifacts.com", json: "bytes")
        let api = makeAPI(stub)
        let url = try XCTUnwrap(URL(string: "https://output.circle-artifacts.com/abc/app.zip"))
        _ = await api.downloadData(from: url)
        XCTAssertEqual(stub.requests.first?.headers["Circle-Token"], "test-token")
    }

    func testPlusIsPercentEncodedInQuery() async throws {
        let stub = StubTransport().on("/pipeline", json: Fixtures.pipelinesPage)
        let api = makeAPI(stub)
        _ = await api.pipelines(projectSlug: "gh/museapphq/Muse", branch: "feature+plus", pageToken: nil)
        let url = try XCTUnwrap(stub.requests.first?.url.absoluteString)
        XCTAssertTrue(url.contains("feature%2Bplus"), "\"+\" must be encoded as %2B; got \(url)")
        XCTAssertFalse(url.contains("feature+plus"), "raw \"+\" would be read as a space by the server")
    }

    func testPageTokenWithPlusIsEncoded() async throws {
        // First page returns a next_page_token containing "+"; the follow-up
        // request must send it percent-encoded, not as a literal "+".
        let firstPage = """
        { "items": [ { "id": "p1", "errors": [], "state": "created", "created_at": "2026-08-14T23:40:50.978Z" } ],
          "next_page_token": "a+b/c" }
        """
        let stub = StubTransport().on(where: { $0.url.absoluteString.contains("/pipeline") }) { request in
            request.url.absoluteString.contains("page-token")
                ? StubReply(json: Fixtures.pipelinesPage2)
                : StubReply(json: firstPage)
        }
        let client = makeClient(stub)
        _ = try await client.pipelines(projectSlug: "gh/museapphq/Muse")
        let secondURL = try XCTUnwrap(stub.requests.dropFirst().first?.url.absoluteString)
        XCTAssertTrue(secondURL.contains("a%2Bb"), "page-token \"+\" must be encoded; got \(secondURL)")
    }

    func testLimitZeroReturnsEmptyWithoutFetching() async throws {
        let stub = StubTransport().on("/pipeline", json: Fixtures.pipelinesPage)
        let client = makeClient(stub)
        let pipelines = try await client.pipelines(projectSlug: "gh/museapphq/Muse", limit: 0)
        XCTAssertTrue(pipelines.isEmpty)
        XCTAssertTrue(stub.requests.isEmpty, "limit 0 should fetch nothing")
    }

    func testTraversalBypassPatternStaysInsideDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("artifacts-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // "....//evil.txt" defeats a naive "../"-strip; component filtering must
        // still keep it inside the target directory.
        let evil = """
        { "items": [ { "path": "....//evil.txt", "node_index": 0,
          "url": "https://output.circle-artifacts.com/abc/evil.txt" } ], "next_page_token": null }
        """
        let stub = StubTransport()
            .on("/artifacts", json: evil)
            .on("output.circle-artifacts.com", json: "PWNED")
        let client = makeClient(stub)
        let downloaded = try await client.downloadArtifacts(projectSlug: "gh/museapphq/Muse", jobNumber: 1, to: tempDir)
        for item in downloaded {
            XCTAssertTrue(item.localURL.standardizedFileURL.path.hasPrefix(tempDir.standardizedFileURL.path),
                          "artifact escaped: \(item.localURL.path)")
        }
    }
}
