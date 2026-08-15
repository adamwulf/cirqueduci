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

    // MARK: - Watch a single job

    func testWaitForJobPollsUntilFinished() async throws {
        let running = """
        { "number": 89693, "name": "mac-release", "status": "running",
          "started_at": "2026-08-14T20:31:00.000Z" }
        """
        let success = """
        { "number": 89693, "name": "mac-release", "status": "success",
          "started_at": "2026-08-14T20:31:00.000Z", "stopped_at": "2026-08-14T20:40:00.000Z", "duration": 540000 }
        """
        let stub = StubTransport().onSequence("/job/", replies: [
            StubReply(json: running),
            StubReply(json: success)
        ])
        let client = makeClient(stub)

        var pollCount = 0
        let outcome = try await client.waitForJob(projectSlug: "gh/museapphq/Muse", jobNumber: 89693,
                                                  pollInterval: 0, timeout: 5) { _ in pollCount += 1 }
        XCTAssertEqual(pollCount, 2)
        guard case .finished(let job) = outcome else { return XCTFail("expected finished, got \(outcome)") }
        XCTAssertEqual(job.status, .success)
    }

    func testWaitForJobTimesOutWhileRunning() async throws {
        let running = """
        { "number": 89693, "name": "mac-release", "status": "running" }
        """
        let stub = StubTransport().on("/job/", json: running)
        let client = makeClient(stub)
        let outcome = try await client.waitForJob(projectSlug: "gh/museapphq/Muse", jobNumber: 89693,
                                                  pollInterval: 0, timeout: 0)
        guard case .timedOut(let job) = outcome else { return XCTFail("expected timedOut, got \(outcome)") }
        XCTAssertFalse(job.status.isFinished, "a still-running job must not be reported finished")
    }

    func testWaitForJobFinishIsNotMisclassifiedWhenCallbackBlocksPastDeadline() async throws {
        // The response arrives finished within budget, but the onPoll callback
        // blocks past the deadline. Classification uses the arrival time, so this
        // is a finish, not a timeout.
        let success = "{ \"number\": 1, \"name\": \"j\", \"status\": \"success\" }"
        let stub = StubTransport().on("/job/", json: success)
        let client = makeClient(stub)
        let outcome = try await client.waitForJob(projectSlug: "gh/museapphq/Muse", jobNumber: 1,
                                                  pollInterval: 0, timeout: 0.1) { _ in
            Thread.sleep(forTimeInterval: 0.25) // block the callback past the deadline
        }
        guard case .finished = outcome else {
            return XCTFail("an in-window finish must survive a slow callback, got \(outcome)")
        }
    }

    func testWaitForJobTimesOutWhenInitialPollReturnsAfterDeadline() async throws {
        // The very first poll takes longer than the whole timeout and returns
        // success. That completion arrived after the deadline, so it is a timeout.
        let success = "{ \"number\": 1, \"name\": \"j\", \"status\": \"success\" }"
        let stub = StubTransport().on(where: { $0.url.absoluteString.contains("/job/") }) { _ in
            StubReply(json: success, delay: 0.3)
        }
        let client = makeClient(stub)
        let outcome = try await client.waitForJob(projectSlug: "gh/museapphq/Muse", jobNumber: 1,
                                                  pollInterval: 0, timeout: 0.1)
        guard case .timedOut = outcome else {
            return XCTFail("a success observed only after the deadline must be a timeout, got \(outcome)")
        }
    }

    // MARK: - Recent activity overview

    func testRecentActivityFiltersOutOfWindowAndAttachesWorkflows() async throws {
        let since = try XCTUnwrap(CircleCIDate.parse("2026-08-14T00:00:00.000Z"))
        let pipelinesJSON = """
        { "items": [
            { "id": "p-new", "number": 20483, "errors": [], "state": "created",
              "created_at": "2026-08-14T20:00:00.000Z", "updated_at": "2026-08-14T20:05:00.000Z",
              "vcs": { "branch": "agent/web-snapshot-selection" } },
            { "id": "p-old", "number": 20000, "errors": [], "state": "created",
              "created_at": "2026-08-10T00:00:00.000Z", "updated_at": "2026-08-10T00:00:00.000Z" }
          ], "next_page_token": null }
        """
        let workflowsJSON = """
        { "items": [
            { "id": "wf-1", "name": "release-deploy", "status": "running", "pipeline_id": "p-new",
              "created_at": "2026-08-14T20:01:00.000Z" },
            { "id": "wf-2", "name": "alpha-deploy", "status": "on_hold", "pipeline_id": "p-new",
              "created_at": "2026-08-14T20:01:00.000Z" }
          ], "next_page_token": null }
        """
        // Register the more-specific "/workflow" matcher first; the pipelines-list
        // URL contains "/pipeline" but not "/workflow", so each routes correctly.
        let stub = StubTransport()
            .on("/workflow", json: workflowsJSON)
            .on("/pipeline", json: pipelinesJSON)
        let client = makeClient(stub)

        let activity = try await client.recentActivity(projectSlug: "gh/museapphq/Muse", since: since)
        XCTAssertEqual(activity.count, 1, "the pipeline older than `since` must be excluded")
        let first = try XCTUnwrap(activity.first)
        XCTAssertEqual(first.pipeline.id, "p-new")
        XCTAssertEqual(first.workflows.count, 2)
        XCTAssertTrue(first.isActive)
        XCTAssertEqual(first.workflowSummary, "1 running, 1 on_hold")
        XCTAssertFalse(stub.requests.contains { $0.url.absoluteString.contains("p-old") },
                       "must not fetch workflows for a pipeline outside the window")
    }

    func testRecentActivityMarksPipelinesWithNoWorkflows() async throws {
        let since = try XCTUnwrap(CircleCIDate.parse("2026-08-14T00:00:00.000Z"))
        let pipelinesJSON = """
        { "items": [
            { "id": "p-tag", "number": 20482, "errors": [], "state": "created",
              "created_at": "2026-08-14T20:00:00.000Z", "updated_at": "2026-08-14T20:00:00.000Z",
              "vcs": { "tag": "builds/macrelease/10876" } }
          ], "next_page_token": null }
        """
        let emptyWorkflows = "{ \"items\": [], \"next_page_token\": null }"
        let stub = StubTransport()
            .on("/workflow", json: emptyWorkflows)
            .on("/pipeline", json: pipelinesJSON)
        let client = makeClient(stub)

        let activity = try await client.recentActivity(projectSlug: "gh/museapphq/Muse", since: since)
        XCTAssertEqual(activity.count, 1)
        XCTAssertEqual(activity.first?.workflowSummary, "no workflows")
        XCTAssertFalse(activity.first?.isActive ?? true)
    }

    func testRecentActivityFollowsNextPageTokenAndFiltersByWindow() async throws {
        let since = try XCTUnwrap(CircleCIDate.parse("2026-08-14T00:00:00.000Z"))
        let page1 = """
        { "items": [
            { "id": "pA", "number": 3, "errors": [], "state": "created", "updated_at": "2026-08-14T20:00:00.000Z" }
          ], "next_page_token": "tok" }
        """
        let page2 = """
        { "items": [
            { "id": "pB", "number": 2, "errors": [], "state": "created", "updated_at": "2026-08-14T10:00:00.000Z" },
            { "id": "pC", "number": 1, "errors": [], "state": "created", "updated_at": "2026-08-10T00:00:00.000Z" }
          ], "next_page_token": null }
        """
        let emptyWorkflows = "{ \"items\": [], \"next_page_token\": null }"
        let stub = StubTransport()
            .on("/workflow", json: emptyWorkflows)
            .on(where: { $0.url.absoluteString.contains("/pipeline") && !$0.url.absoluteString.contains("/workflow") }) { request in
                request.url.absoluteString.contains("page-token") ? StubReply(json: page2) : StubReply(json: page1)
            }
        let client = makeClient(stub)

        let activity = try await client.recentActivity(projectSlug: "gh/museapphq/Muse", since: since)
        XCTAssertEqual(activity.map { $0.pipeline.id }, ["pA", "pB"], "spans pages, keeps only in-window pipelines")
        let listRequests = stub.requests.filter {
            $0.url.absoluteString.contains("/pipeline") && !$0.url.absoluteString.contains("/workflow")
        }
        XCTAssertEqual(listRequests.count, 2, "must follow next_page_token to the second page")
        XCTAssertFalse(stub.requests.contains { $0.url.absoluteString.contains("pC") },
                       "must not fetch workflows for a pipeline outside the window")
    }

    func testRecentActivityKeepsRecentlyRerunOldPipelineBelowTheBoundary() async throws {
        // The list is ordered by creation, so an old pipeline rerun today sits
        // BELOW a pipeline last updated just before the window. Early-stopping on
        // the first out-of-window entry would wrongly drop the rerun; filtering
        // each pipeline independently keeps it.
        let since = try XCTUnwrap(CircleCIDate.parse("2026-08-14T00:00:00.000Z"))
        let page = """
        { "items": [
            { "id": "pTop", "number": 3, "errors": [], "state": "created",
              "created_at": "2026-08-14T20:00:00.000Z", "updated_at": "2026-08-14T20:05:00.000Z" },
            { "id": "pMid", "number": 2, "errors": [], "state": "created",
              "created_at": "2026-08-13T23:00:00.000Z", "updated_at": "2026-08-13T23:30:00.000Z" },
            { "id": "pRerun", "number": 1, "errors": [], "state": "created",
              "created_at": "2026-08-10T00:00:00.000Z", "updated_at": "2026-08-14T21:00:00.000Z" }
          ], "next_page_token": null }
        """
        let emptyWorkflows = "{ \"items\": [], \"next_page_token\": null }"
        let stub = StubTransport()
            .on("/workflow", json: emptyWorkflows)
            .on(where: { $0.url.absoluteString.contains("/pipeline") && !$0.url.absoluteString.contains("/workflow") }) { _ in StubReply(json: page) }
        let client = makeClient(stub)

        let activity = try await client.recentActivity(projectSlug: "gh/museapphq/Muse", since: since)
        XCTAssertEqual(activity.map { $0.pipeline.id }, ["pTop", "pRerun"],
                       "the recently rerun old pipeline must survive even though an out-of-window one precedes it")
    }

    func testRecentActivityIncludesBoundaryAndRespectsCap() async throws {
        let since = try XCTUnwrap(CircleCIDate.parse("2026-08-14T00:00:00.000Z"))
        let page = """
        { "items": [
            { "id": "pA", "number": 3, "errors": [], "state": "created", "updated_at": "2026-08-14T20:00:00.000Z" },
            { "id": "pBoundary", "number": 2, "errors": [], "state": "created", "updated_at": "2026-08-14T00:00:00.000Z" },
            { "id": "pOld", "number": 1, "errors": [], "state": "created", "updated_at": "2026-08-13T23:59:59.000Z" }
          ], "next_page_token": null }
        """
        let emptyWorkflows = "{ \"items\": [], \"next_page_token\": null }"
        func makeStub() -> StubTransport {
            StubTransport()
                .on("/workflow", json: emptyWorkflows)
                .on(where: { $0.url.absoluteString.contains("/pipeline") && !$0.url.absoluteString.contains("/workflow") }) { _ in StubReply(json: page) }
        }

        // Inclusive lower bound: the pipeline exactly at `since` is kept; the one
        // a second earlier is dropped and stops the scan.
        let all = try await makeClient(makeStub()).recentActivity(projectSlug: "gh/museapphq/Muse", since: since)
        XCTAssertEqual(all.map { $0.pipeline.id }, ["pA", "pBoundary"])

        // Cap: never return more than maxPipelines.
        let capped = try await makeClient(makeStub()).recentActivity(projectSlug: "gh/museapphq/Muse", since: since, maxPipelines: 1)
        XCTAssertEqual(capped.map { $0.pipeline.id }, ["pA"])
    }

    // MARK: - Exit-code semantics

    func testJobFailureClassificationTreatsNotRunAsAPass() throws {
        // `watch` exits 1 only on a genuine failure. A skipped (not_run) or
        // superseded (retried) job is a pass, not a failure.
        XCTAssertFalse(JobStatus.notRun.isFailure)
        XCTAssertFalse(JobStatus.retried.isFailure)
        XCTAssertFalse(JobStatus.success.isFailure)
        XCTAssertTrue(JobStatus.failed.isFailure)
        XCTAssertTrue(JobStatus.timedout.isFailure)
        XCTAssertTrue(JobStatus.canceled.isFailure)
        XCTAssertTrue(JobStatus.infrastructureFail.isFailure)
    }

    // MARK: - Timeout is honored, not rounded up to the poll interval

    func testWaitForJobReturnsByDeadlineNotFullInterval() async throws {
        let running = "{ \"number\": 1, \"name\": \"j\", \"status\": \"running\" }"
        let stub = StubTransport().on("/job/", json: running)
        let client = makeClient(stub)

        let start = Date()
        let outcome = try await client.waitForJob(projectSlug: "gh/museapphq/Muse", jobNumber: 1,
                                                  pollInterval: 10, timeout: 0.2)
        let elapsed = Date().timeIntervalSince(start)
        guard case .timedOut = outcome else { return XCTFail("expected timedOut, got \(outcome)") }
        XCTAssertLessThan(elapsed, 3, "must return near the 0.2s timeout, not sleep the 10s interval")
    }

    func testWaitForJobReportsTimeoutWhenCompletionIsObservedAfterDeadline() async throws {
        // First poll: fast, still running. Second poll: returns success, but only
        // after a delay (slow request / retry backoff) that lands past the
        // deadline. That late completion must not mask the timeout.
        let running = "{ \"number\": 1, \"name\": \"j\", \"status\": \"running\" }"
        let success = "{ \"number\": 1, \"name\": \"j\", \"status\": \"success\" }"
        var call = 0
        let stub = StubTransport().on(where: { $0.url.absoluteString.contains("/job/") }) { _ in
            call += 1
            return call == 1 ? StubReply(json: running) : StubReply(json: success, delay: 0.3)
        }
        let client = makeClient(stub)

        let outcome = try await client.waitForJob(projectSlug: "gh/museapphq/Muse", jobNumber: 1,
                                                  pollInterval: 0, timeout: 0.1)
        guard case .timedOut = outcome else {
            return XCTFail("a success seen only after the deadline must be a timeout, got \(outcome)")
        }
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
