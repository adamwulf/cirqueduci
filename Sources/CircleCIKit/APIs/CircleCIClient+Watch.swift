//
//  CircleCIClient+Watch.swift
//  cirqueduci
//
//  Polling a pipeline's workflows until they all finish is real logic, so it
//  lives in the library. The CLI supplies a callback to render each poll.
//

import Foundation

extension CircleCIClient {

    /// True once every workflow in the list has reached a terminal status.
    public static func allFinished(_ workflows: [Workflow]) -> Bool {
        !workflows.isEmpty && workflows.allSatisfy { $0.status.isFinished }
    }

    /// The workflow statuses that count as an unsuccessful outcome.
    private static let failureStatuses: Set<WorkflowStatus> = [.failed, .error, .canceled, .unauthorized]

    /// True when any workflow ended in an unsuccessful status.
    public static func anyFailed(_ workflows: [Workflow]) -> Bool {
        workflows.contains { failureStatuses.contains($0.status) }
    }

    /// True only when every workflow succeeded. This is the exit-0 condition:
    /// anything else terminal (including `not_run`) is not a success, matching
    /// the single-job rule (`status == .success`).
    public static func allSucceeded(_ workflows: [Workflow]) -> Bool {
        !workflows.isEmpty && workflows.allSatisfy { $0.status == .success }
    }

    /// Sleeps `seconds`, but never a non-positive amount (which would trap the
    /// `UInt64` conversion and, at 0, busy-spin). Callers pass the time left
    /// until the deadline so a poll never overshoots the caller's timeout.
    private static func nap(_ seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Polls a pipeline's workflows until they all finish (or `timeout`
    /// elapses). `onPoll` is called with the current workflows after each fetch.
    /// Returns the final workflow list.
    @discardableResult
    public func waitForPipeline(id: String,
                                pollInterval: TimeInterval = 5,
                                timeout: TimeInterval = 1800,
                                onPoll: (([Workflow]) -> Void)? = nil) async throws -> [Workflow] {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let workflows = try await self.workflows(pipelineId: id)
            onPoll?(workflows)

            if Self.allFinished(workflows) {
                return workflows
            }
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                return workflows
            }
            try await Self.nap(min(pollInterval, remaining))
        }
    }

    /// Polls one build job (by project + number) until it reaches a terminal
    /// status (or `timeout` elapses). `onPoll` is called with the current job
    /// detail after each fetch. Returns the final job detail.
    @discardableResult
    public func waitForJob(projectSlug: String,
                           jobNumber: Int,
                           pollInterval: TimeInterval = 60,
                           timeout: TimeInterval = 1800,
                           onPoll: ((JobDetail) -> Void)? = nil) async throws -> JobDetail {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let job = try await self.jobDetail(projectSlug: projectSlug, jobNumber: jobNumber)
            onPoll?(job)

            if job.status.isFinished {
                return job
            }
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                return job
            }
            try await Self.nap(min(pollInterval, remaining))
        }
    }
}
