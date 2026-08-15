import XCTest
@testable import CircleCIKit

/// Decodes canned CircleCI JSON straight into models (no client), exactly like
/// hunch's ModelTests. Uses the shared CircleCIJSON.decoder so the date/coding
/// settings match the real API client.
final class ModelTests: XCTestCase {

    private let decoder = CircleCIJSON.decoder

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try decoder.decode(T.self, from: Data(json.utf8))
    }

    // MARK: - Identity

    func testMeDecode() throws {
        let me = try decode(Me.self, Fixtures.me)
        XCTAssertEqual(me.id, "98209bd9-c440-45b0-b1d7-749a15860f58")
        XCTAssertEqual(me.login, "adamwulf")
        XCTAssertEqual(me.name, "Adam Wulf")
    }

    func testCollaborationsDecode() throws {
        let collaborations = try decode([Collaboration].self, Fixtures.collaborations)
        XCTAssertEqual(collaborations.count, 1)
        XCTAssertEqual(collaborations.first?.slug, "gh/museapphq")
        XCTAssertEqual(collaborations.first?.vcsType, "github")
        XCTAssertEqual(collaborations.first?.name, "museapphq")
    }

    // MARK: - Projects

    func testFollowedProjectDecodeAndSlug() throws {
        let projects = try decode([FollowedProject].self, Fixtures.followedProjects)
        XCTAssertEqual(projects.count, 1)
        let project = try XCTUnwrap(projects.first)
        XCTAssertEqual(project.reponame, "Muse")
        XCTAssertEqual(project.username, "museapphq")
        XCTAssertEqual(project.following, true)
        // v1.1 "github" maps to the v2 short form "gh".
        XCTAssertEqual(project.slug, "gh/museapphq/Muse")
    }

    func testProjectDecode() throws {
        let project = try decode(Project.self, Fixtures.project)
        XCTAssertEqual(project.id, "06a9bd5a-be08-4b9d-86cb-edbb17e5c1c7")
        XCTAssertEqual(project.slug, "gh/museapphq/Muse")
        XCTAssertEqual(project.organizationSlug, "gh/museapphq")
        XCTAssertEqual(project.vcsInfo?.defaultBranch, "main")
        XCTAssertEqual(project.vcsInfo?.provider, "GitHub")
    }

    // MARK: - Pipelines

    func testPipelinesPageDecode() throws {
        let page = try decode(Paged<Pipeline>.self, Fixtures.pipelinesPage)
        XCTAssertNil(page.nextPageToken)
        XCTAssertEqual(page.items.count, 1)
        let pipeline = try XCTUnwrap(page.items.first)
        XCTAssertEqual(pipeline.id, "1cfafffe-3869-47c9-8941-b972e5dea8bf")
        XCTAssertEqual(pipeline.number, 12345)
        XCTAssertEqual(pipeline.state, .created)
        XCTAssertTrue(pipeline.state.isFinished)
        XCTAssertEqual(pipeline.vcs?.branch, "agent/web-snapshot-selection")
        XCTAssertEqual(pipeline.vcs?.commit?.subject, "Fix Phase 1 build: missing Locks/SwiftToolbox imports")
        XCTAssertEqual(pipeline.trigger?.actor?.login, "adamwulf")
        XCTAssertNotNil(pipeline.createdAt)
    }

    func testPipelineDecodeWithoutErrorsField() throws {
        // The trigger response and some payloads omit "errors"; it must default to [].
        let json = """
        { "id": "p1", "state": "created", "created_at": "2026-08-14T23:40:50.978Z" }
        """
        let pipeline = try decode(Pipeline.self, json)
        XCTAssertEqual(pipeline.id, "p1")
        XCTAssertEqual(pipeline.errors.count, 0)
        XCTAssertNil(pipeline.number)
    }

    // MARK: - Workflows

    func testWorkflowsPageDecode() throws {
        let page = try decode(Paged<Workflow>.self, Fixtures.workflowsPage)
        let workflow = try XCTUnwrap(page.items.first)
        XCTAssertEqual(workflow.name, "release-deploy")
        XCTAssertEqual(workflow.status, .onHold)
        XCTAssertFalse(workflow.status.isFinished)
        XCTAssertTrue(workflow.status.isRunning)
        XCTAssertEqual(workflow.pipelineId, "1cfafffe-3869-47c9-8941-b972e5dea8bf")
    }

    func testWorkflowStatusFinished() throws {
        let workflow = try decode(Workflow.self, Fixtures.workflowFinished)
        XCTAssertEqual(workflow.status, .success)
        XCTAssertTrue(workflow.status.isFinished)
        XCTAssertNotNil(workflow.stoppedAt)
    }

    // MARK: - Jobs

    func testJobsPageDecodeAndApprovalDetection() throws {
        let page = try decode(Paged<Job>.self, Fixtures.jobsPage)
        XCTAssertEqual(page.items.count, 3)

        let approval = try XCTUnwrap(page.items.first { $0.type == .approval })
        XCTAssertEqual(approval.name, "approve-mac-release")
        XCTAssertEqual(approval.status, .onHold)
        XCTAssertTrue(approval.isApprovable)
        XCTAssertEqual(approval.approvalRequestId, "58ae7914-6179-4a77-8b30-d324afaf048f")
        XCTAssertEqual(approval.effectiveApprovalRequestId, "58ae7914-6179-4a77-8b30-d324afaf048f")
        XCTAssertNil(approval.jobNumber)

        let build = try XCTUnwrap(page.items.first { $0.name == "slack/approval-notification-1" })
        XCTAssertEqual(build.type, .build)
        XCTAssertEqual(build.status, .success)
        XCTAssertEqual(build.jobNumber, 40796)
        XCTAssertFalse(build.isApprovable)

        let blocked = try XCTUnwrap(page.items.first { $0.name == "mac-release" })
        XCTAssertEqual(blocked.status, .blocked)
        XCTAssertEqual(blocked.dependencies, ["58ae7914-6179-4a77-8b30-d324afaf048f"])
    }

    func testEffectiveApprovalRequestIdFallsBackToId() throws {
        // When approval_request_id is absent, fall back to the job's own id.
        let json = """
        { "id": "gate-id", "name": "approve", "type": "approval", "status": "on_hold" }
        """
        let job = try decode(Job.self, json)
        XCTAssertNil(job.approvalRequestId)
        XCTAssertEqual(job.effectiveApprovalRequestId, "gate-id")
        XCTAssertTrue(job.isApprovable)
    }

    // MARK: - Job detail, steps, logs

    func testJobDetailDecode() throws {
        let detail = try decode(JobDetail.self, Fixtures.jobDetail)
        XCTAssertEqual(detail.number, 40796)
        XCTAssertEqual(detail.status, .success)
        XCTAssertEqual(detail.webURL, "https://circleci.com/gh/museapphq/Muse/40796")
        XCTAssertEqual(detail.latestWorkflow?.name, "release-deploy")
        XCTAssertEqual(detail.parallelRuns?.first?.status, .success)
        XCTAssertEqual(detail.duration, 8000)
    }

    func testJobStepsDecode() throws {
        let response = try decode(JobStepsResponse.self, Fixtures.jobSteps)
        XCTAssertEqual(response.steps.count, 2)
        let spinup = try XCTUnwrap(response.steps.first)
        XCTAssertEqual(spinup.name, "Spin up environment")
        let action = try XCTUnwrap(spinup.actions.first)
        XCTAssertEqual(action.type, "spinup_environment")
        XCTAssertEqual(action.runTimeMillis, 8035)
        XCTAssertTrue(action.outputURL?.contains("step-0") ?? false)
        XCTAssertNil(action.exitCode) // "exit_code": null
    }

    func testStepLogDecode() throws {
        let lines = try decode([LogLine].self, Fixtures.stepLog)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines.first?.type, "out")
        XCTAssertEqual(lines.map { $0.message }.joined(), "Starting slack notification\nDone.\n")
    }

    // MARK: - Artifacts, tests, trigger

    func testArtifactsPageDecode() throws {
        let page = try decode(Paged<Artifact>.self, Fixtures.artifactsPage)
        XCTAssertEqual(page.items.count, 2)
        XCTAssertEqual(page.items.first?.path, "test-results/results.xml")
        XCTAssertEqual(page.items.first?.nodeIndex, 0)
    }

    func testTestsPageDecode() throws {
        let page = try decode(Paged<TestResult>.self, Fixtures.testsPage)
        let test = try XCTUnwrap(page.items.first)
        XCTAssertEqual(test.result, "success")
        XCTAssertEqual(test.classname, "FooTests")
        XCTAssertEqual(test.runTime, 0.12)
    }

    func testTriggerResponseDecode() throws {
        let response = try decode(TriggerPipelineResponse.self, Fixtures.triggerResponse)
        XCTAssertEqual(response.id, "new-pipeline-uuid")
        XCTAssertEqual(response.number, 12346)
        XCTAssertEqual(response.state, .created)
    }

    // MARK: - Status forward-compatibility

    func testUnknownStatusDecodesVerbatim() throws {
        let status = try decode(JobStatus.self, "\"some_future_status\"")
        XCTAssertEqual(status.rawValue, "some_future_status")
        XCTAssertFalse(status.isFinished)
    }

    // MARK: - Parameter values

    func testParameterValueParsing() {
        XCTAssertEqual(ParameterValue.parse("true"), .bool(true))
        XCTAssertEqual(ParameterValue.parse("false"), .bool(false))
        XCTAssertEqual(ParameterValue.parse("42"), .int(42))
        XCTAssertEqual(ParameterValue.parse("hello"), .string("hello"))

        let pair = ParameterValue.parsePair("run_beta=true")
        XCTAssertEqual(pair?.0, "run_beta")
        XCTAssertEqual(pair?.1, .bool(true))
        XCTAssertNil(ParameterValue.parsePair("noequals"))
        XCTAssertNil(ParameterValue.parsePair("=value"))
    }

    func testTriggerRequestEncodesParameters() throws {
        let request = TriggerPipelineRequest(branch: "main",
                                             parameters: ["deploy": .bool(true), "count": .int(3)])
        let data = try CircleCIJSON.encoder.encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["branch"] as? String, "main")
        let parameters = object?["parameters"] as? [String: Any]
        XCTAssertEqual(parameters?["deploy"] as? Bool, true)
        XCTAssertEqual(parameters?["count"] as? Int, 3)
    }
}
