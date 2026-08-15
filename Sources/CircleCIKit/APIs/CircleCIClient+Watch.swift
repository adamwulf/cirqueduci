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
        var lastInWindow = try await self.jobDetail(projectSlug: projectSlug, jobNumber: jobNumber)
        onPoll?(lastInWindow)
        while true {
            if lastInWindow.status.isFinished {
                return lastInWindow
            }
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                return lastInWindow // out of budget, still running -> timeout
            }
            try await Self.nap(min(pollInterval, remaining))

            let observed = try await self.jobDetail(projectSlug: projectSlug, jobNumber: jobNumber)
            onPoll?(observed)
            if Date() >= deadline {
                // This poll returned after the deadline — a slow request or retry
                // backoff can overrun it. Honor the timeout: a completion seen
                // only now must not count, so report the last in-window state.
                return observed.status.isFinished ? lastInWindow : observed
            }
            lastInWindow = observed
        }
    }
}
