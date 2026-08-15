import XCTest
import ArgumentParser
@testable import cirqueduci
@testable import CircleCIKit

/// Pure ArgumentParser parsing + validation tests — no network, mirroring
/// hunch's CLITests. Verifies the thin CLI maps flags to the right values and
/// rejects invalid combinations before any library call.
final class CommandParsingTests: XCTestCase {

    // MARK: - pipelines

    func testPipelinesByProject() throws {
        let command = try PipelinesCommand.parse(["--project", "gh/museapphq/Muse", "--limit", "5", "--format", "json"])
        XCTAssertEqual(command.project, "gh/museapphq/Muse")
        XCTAssertEqual(command.limit, 5)
        XCTAssertEqual(command.format, .json)
        XCTAssertNil(command.org)
    }

    func testPipelinesByOrgMine() throws {
        let command = try PipelinesCommand.parse(["--org", "gh/museapphq", "--mine"])
        XCTAssertEqual(command.org, "gh/museapphq")
        XCTAssertTrue(command.mine)
    }

    func testPipelinesSinglePositional() throws {
        let command = try PipelinesCommand.parse(["1cfafffe-3869-47c9-8941-b972e5dea8bf"])
        XCTAssertEqual(command.pipelineId, "1cfafffe-3869-47c9-8941-b972e5dea8bf")
    }

    func testPipelinesRequiresATarget() {
        XCTAssertThrowsError(try PipelinesCommand.parse([]))
    }

    // MARK: - workflows / jobs

    func testWorkflowsByPipeline() throws {
        let command = try WorkflowsCommand.parse(["pipeline-id"])
        XCTAssertEqual(command.pipelineId, "pipeline-id")
    }

    func testWorkflowsById() throws {
        let command = try WorkflowsCommand.parse(["--id", "wf-id"])
        XCTAssertEqual(command.id, "wf-id")
    }

    func testWorkflowsRequiresATarget() {
        XCTAssertThrowsError(try WorkflowsCommand.parse([]))
    }

    func testJobsWithApprovableFlag() throws {
        let command = try JobsCommand.parse(["wf-id", "--approvable"])
        XCTAssertEqual(command.workflowId, "wf-id")
        XCTAssertTrue(command.approvable)
    }

    // MARK: - job-scoped (locator)

    func testStepsLocator() throws {
        let command = try StepsCommand.parse(["40796", "--project", "gh/museapphq/Muse"])
        XCTAssertEqual(command.locator.jobNumber, 40796)
        XCTAssertEqual(command.locator.project, "gh/museapphq/Muse")
    }

    func testLogsStepFilter() throws {
        let command = try LogsCommand.parse(["40796", "-p", "gh/museapphq/Muse", "--step", "Spin up environment", "--raw"])
        XCTAssertEqual(command.locator.jobNumber, 40796)
        XCTAssertEqual(command.step, "Spin up environment")
        XCTAssertTrue(command.raw)
    }

    func testArtifactsDownload() throws {
        let command = try ArtifactsCommand.parse(["40796", "-p", "gh/museapphq/Muse", "--download", "/tmp/out"])
        XCTAssertEqual(command.download, "/tmp/out")
    }

    // MARK: - approve

    func testApproveByName() throws {
        let command = try ApproveCommand.parse(["d6e3cf7a", "--job", "approve-mac-release"])
        XCTAssertEqual(command.workflowId, "d6e3cf7a")
        XCTAssertEqual(command.job, "approve-mac-release")
    }

    func testApproveByRequestId() throws {
        let command = try ApproveCommand.parse(["d6e3cf7a", "--approval-request-id", "58ae7914"])
        XCTAssertEqual(command.approvalRequestId, "58ae7914")
    }

    // MARK: - trigger

    func testTriggerWithParams() throws {
        let command = try TriggerCommand.parse(["--project", "gh/museapphq/Muse", "--branch", "main",
                                                "--param", "deploy=true", "--param", "count=3"])
        XCTAssertEqual(command.project, "gh/museapphq/Muse")
        XCTAssertEqual(command.branch, "main")
        XCTAssertEqual(command.params, ["deploy=true", "count=3"])
    }

    func testTriggerRequiresBranchOrTag() {
        XCTAssertThrowsError(try TriggerCommand.parse(["--project", "gh/museapphq/Muse"]))
    }

    func testTriggerRejectsBothBranchAndTag() {
        XCTAssertThrowsError(try TriggerCommand.parse(["--project", "x", "--branch", "main", "--tag", "v1"]))
    }

    func testTriggerRejectsBadParam() {
        XCTAssertThrowsError(try TriggerCommand.parse(["--project", "x", "--branch", "main", "--param", "noequals"]))
    }

    // MARK: - watch defaults

    func testWatchDefaults() throws {
        let command = try WatchCommand.parse(["pipeline-id"])
        XCTAssertEqual(command.pipelineId, "pipeline-id")
        XCTAssertEqual(command.interval, 5)
        XCTAssertEqual(command.timeout, 1800)
    }

    // MARK: - root

    func testRootHasAllSubcommands() {
        let names = Cirqueduci.configuration.subcommands.map { $0.configuration.commandName }
        for expected in ["me", "projects", "pipelines", "workflows", "jobs", "job", "steps",
                         "logs", "artifacts", "tests", "trigger", "approve", "cancel", "rerun", "watch"] {
            XCTAssertTrue(names.contains(expected), "missing subcommand: \(expected)")
        }
    }
}
