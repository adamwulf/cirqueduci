//
//  CircleCIClient+Watch.swift
//  cirqueduci
//
//  Polling a build job until it reaches a terminal status is real logic, so it
//  lives in the library. The CLI supplies a callback to render each poll.
//

import Foundation

extension CircleCIClient {

    /// Sleeps `seconds`, but never a non-positive amount (which would trap the
    /// `UInt64` conversion and, at 0, busy-spin). Callers pass the time left
    /// until the deadline so a poll never overshoots the caller's timeout.
    private static func nap(_ seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
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
        var job: JobDetail
        repeat {
            job = try await self.jobDetail(projectSlug: projectSlug, jobNumber: jobNumber)
            onPoll?(job)

            if job.status.isFinished {
                return job
            }
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                break
            }
            try await Self.nap(min(pollInterval, remaining))
            // Re-check the deadline after sleeping: a completion observed only
            // on a post-deadline fetch must not mask the timeout.
        } while Date() < deadline
        return job
    }
}
