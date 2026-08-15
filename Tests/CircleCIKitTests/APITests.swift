import XCTest
@testable import CircleCIKit

/// Exercises the API client end-to-end with a StubTransport: no live network,
/// canned JSON in, decoded models out. Also asserts on the OUTGOING requests
/// (URL, method, headers, pagination) — coverage hunch's design can't reach.
final class APITests: XCTestCase {

    private func makeAPI(_ stub: StubTransport, token: String? = "test-token") -> CircleCIAPI {
        CircleCIAPI(transport: stub, token: token)
    }

    private func makeClient(_ stub: StubTransport, token: String? = "test-token") -> CircleCIClient {
        CircleCIClient(transport: stub, token: token)
    }

    // MARK: - Auth & headers

    func testSendsCircleTokenHeader() async throws {
        let stub = StubTransport().on("/me", json: Fixtures.me)
        let api = makeAPI(stub, token: "secret-token")
        _ = await api.me()
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.headers["Circle-Token"], "secret-token")
        XCTAssertEqual(request.headers["Accept"], "application/json")
        XCTAssertTrue(request.url.absoluteString.hasSuffix("/api/v2/me"))
    }

    func testMissingTokenShortCircuitsBeforeNetwork() async {
        let stub = StubTransport().on("/me", json: Fixtures.me)
        let api = makeAPI(stub, token: nil)
        let result = await api.me()
        if case .failure(let error) = result, case .missingToken = error {
            // expected
        } else {
            XCTFail("expected .missingToken, got \(result)")
        }
        XCTAssertTrue(stub.requests.isEmpty, "no request should be sent without a token")
    }

    // MARK: - URL building

    func testProjectSlugPreservedInPath() async {
        let stub = StubTransport().on("/project/", json: Fixtures.project)
        let api = makeAPI(stub)
        _ = await api.project(slug: "gh/museapphq/Muse")
        XCTAssertEqual(stub.requests.first?.url.absoluteString,
                       "https://circleci.com/api/v2/project/gh/museapphq/Muse")
    }

    func testBranchGoesToQueryEncoded() async {
        let stub = StubTransport().on("/pipeline", json: Fixtures.pipelinesPage)
        let api = makeAPI(stub)
        _ = await api.pipelines(projectSlug: "gh/museapphq/Muse", branch: "agent/web-snapshot-selection", pageToken: nil)
        let url = try? XCTUnwrap(stub.requests.first?.url.absoluteString)
        XCTAssertEqual(url?.contains("branch=agent/web-snapshot-selection") == true
                       || url?.contains("branch=agent%2Fweb-snapshot-selection") == true, true,
                       "branch should be a (URL-encoded) query item; got \(url ?? "nil")")
    }

    func testJobStepsUsesV11LongSlug() async {
        let stub = StubTransport().on("/api/v1.1/project/", json: Fixtures.jobSteps)
        let client = makeClient(stub)
        _ = try? await client.jobSteps(projectSlug: "gh/museapphq/Muse", jobNumber: 40796)
        let url = try? XCTUnwrap(stub.requests.first?.url.absoluteString)
        XCTAssertEqual(url, "https://circleci.com/api/v1.1/project/github/museapphq/Muse/40796")
    }

    // MARK: - Pagination (facade)

    func testPaginationFollowsNextPageToken() async throws {
        let stub = StubTransport().on(where: { $0.url.absoluteString.contains("/pipeline") }) { request in
            if request.url.absoluteString.contains("page-token=PAGE2") {
                return StubReply(json: Fixtures.pipelinesPage2)
            }
            return StubReply(json: Fixtures.pipelinesPage1)
        }
        let client = makeClient(stub)
        let pipelines = try await client.pipelines(projectSlug: "gh/museapphq/Muse")
        XCTAssertEqual(pipelines.map { $0.id }, ["pipeline-1", "pipeline-2"])
        XCTAssertEqual(stub.requests.count, 2)
        XCTAssertTrue(stub.requests[1].url.absoluteString.contains("page-token=PAGE2"))
    }

    func testPaginationRespectsLimit() async throws {
        let stub = StubTransport().on(where: { $0.url.absoluteString.contains("/pipeline") }) { request in
            if request.url.absoluteString.contains("page-token=PAGE2") {
                return StubReply(json: Fixtures.pipelinesPage2)
            }
            return StubReply(json: Fixtures.pipelinesPage1)
        }
        let client = makeClient(stub)
        let pipelines = try await client.pipelines(projectSlug: "gh/museapphq/Muse", limit: 1)
        XCTAssertEqual(pipelines.count, 1)
        XCTAssertEqual(stub.requests.count, 1, "limit reached on page 1 should not fetch page 2")
    }

    // MARK: - Workflows & jobs

    func testWorkflowsAndJobs() async throws {
        let stub = StubTransport()
            .on("/workflow", method: "GET", json: Fixtures.jobsPage) // matches /workflow/{id}/job
        let client = makeClient(stub)
        let jobs = try await client.jobs(workflowId: "d6e3cf7a-5419-4f7a-bb71-91e8370a3f4b")
        XCTAssertEqual(jobs.count, 3)
        let approvable = jobs.filter { $0.isApprovable }
        XCTAssertEqual(approvable.map { $0.name }, ["approve-mac-release"])
    }

    // MARK: - Approve

    func testApproveJobPostsToApproveEndpoint() async throws {
        let stub = StubTransport().on("/approve/", method: "POST", json: Fixtures.approveAccepted)
        let client = makeClient(stub)
        let response = try await client.approveJob(workflowId: "wf-1", approvalRequestId: "ar-1")
        XCTAssertEqual(response.message, "Accepted.")
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.absoluteString, "https://circleci.com/api/v2/workflow/wf-1/approve/ar-1")
    }

    func testApproveByNameResolvesTheGate() async throws {
        let stub = StubTransport()
            .on("/approve/", method: "POST", json: Fixtures.approveAccepted)
            .on("/job", method: "GET", json: Fixtures.jobsPage)
        let client = makeClient(stub)
        let approved = try await client.approveJob(workflowId: "d6e3cf7a", named: "approve-mac-release")
        XCTAssertEqual(approved.name, "approve-mac-release")
        // The approve POST must target the gate's approval_request_id.
        let approvePost = try XCTUnwrap(stub.requests.first { $0.method == "POST" })
        XCTAssertTrue(approvePost.url.absoluteString.hasSuffix("/approve/58ae7914-6179-4a77-8b30-d324afaf048f"))
    }

    func testApproveWithoutNameWhenSingleGate() async throws {
        let singleGate = """
        { "items": [ { "id": "g1", "name": "approve-only", "type": "approval", "status": "on_hold",
          "approval_request_id": "g1" } ], "next_page_token": null }
        """
        let stub = StubTransport()
            .on("/approve/", method: "POST", json: Fixtures.approveAccepted)
            .on("/job", method: "GET", json: singleGate)
        let client = makeClient(stub)
        let approved = try await client.approveJob(workflowId: "wf", named: nil)
        XCTAssertEqual(approved.name, "approve-only")
    }

    func testApproveWithoutNameThrowsWhenMultipleGates() async {
        let twoGates = """
        { "items": [
          { "id": "g1", "name": "approve-mac", "type": "approval", "status": "on_hold", "approval_request_id": "g1" },
          { "id": "g2", "name": "approve-ios", "type": "approval", "status": "on_hold", "approval_request_id": "g2" }
        ], "next_page_token": null }
        """
        let stub = StubTransport().on("/job", method: "GET", json: twoGates)
        let client = makeClient(stub)
        do {
            _ = try await client.approveJob(workflowId: "wf", named: nil)
            XCTFail("expected an error when multiple gates and no name")
        } catch {
            // expected
        }
    }

    // MARK: - Trigger

    func testTriggerPostsBranchBody() async throws {
        let stub = StubTransport().on("/pipeline", method: "POST", status: 201, json: Fixtures.triggerResponse)
        let client = makeClient(stub)
        let response = try await client.triggerPipeline(projectSlug: "gh/museapphq/Muse",
                                                        branch: "main",
                                                        parameters: ["deploy": .bool(true)])
        XCTAssertEqual(response.number, 12346)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        let body = try XCTUnwrap(request.body)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(object?["branch"] as? String, "main")
        XCTAssertEqual((object?["parameters"] as? [String: Any])?["deploy"] as? Bool, true)
    }

    // MARK: - Errors

    func testErrorStatusSurfacesMessage() async {
        let stub = StubTransport().on("/me", status: 404, json: "{\"message\":\"Not Found\"}")
        let api = makeAPI(stub)
        let result = await api.me()
        if case .failure(let error) = result, case .invalidResponseStatus(let status, let message) = error {
            XCTAssertEqual(status, 404)
            XCTAssertEqual(message, "{\"message\":\"Not Found\"}")
        } else {
            XCTFail("expected .invalidResponseStatus, got \(result)")
        }
    }

    // MARK: - Logs & downloads

    func testJobLogsAssemblesStepOutput() async throws {
        let stub = StubTransport()
            .on("/api/v1.1/project/", json: Fixtures.jobSteps)
            .on("s3.amazonaws.com", json: Fixtures.stepLog)
        let client = makeClient(stub)
        let logs = try await client.jobLogs(projectSlug: "gh/museapphq/Muse", jobNumber: 40796)
        XCTAssertEqual(logs.count, 2) // two steps, each with one action carrying an output_url
        XCTAssertEqual(logs.first?.text, "Starting slack notification\nDone.\n")
    }

    func testPreSignedDownloadSendsNoToken() async throws {
        let stub = StubTransport().on("s3.amazonaws.com", json: Fixtures.stepLog)
        let api = makeAPI(stub)
        let url = try XCTUnwrap(URL(string: "https://circle-production.s3.amazonaws.com/step-102?sig=def"))
        _ = await api.stepLog(outputURL: url)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertNil(request.headers["Circle-Token"], "pre-signed S3 URLs must not carry the Circle-Token")
    }

    func testDownloadDataReturnsBytes() async throws {
        let stub = StubTransport().on("output.circle-artifacts.com", json: "{\"ok\":true}")
        let client = makeClient(stub)
        let url = try XCTUnwrap(URL(string: "https://output.circle-artifacts.com/abc/build/app.zip"))
        let data = try await client.downloadData(from: url)
        XCTAssertEqual(String(data: data, encoding: .utf8), "{\"ok\":true}")
    }
}
