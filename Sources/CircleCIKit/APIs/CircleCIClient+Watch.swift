//
//  CircleCIClient+Watch.swift
//  cirqueduci
//
//  Polling a build job until it reaches a terminal status is real logic, so it
//  lives in the library. The CLI supplies a callback to render each poll.
//

import Foundation

/// The result of waiting on a job. A terminal status counts only if it is
/// observed within the timeout budget; anything else (including a completion
/// seen only on a post-deadline poll) is a timeout carrying the last snapshot.
public enum JobWaitOutcome {
    case finished(JobDetail)
    case timedOut(JobDetail)

    /// The most recent job snapshot, whatever the outcome.
    public var job: JobDetail {
        switch self {
        case .finished(let job), .timedOut(let job): return job
        }
    }
}

extension CircleCIClient {

    /// The longest a single sleep is allowed to be (~292 years). Keeps the
    /// `TimeInterval → UInt64` nanosecond conversion from trapping on absurdly
    /// large intervals/timeouts.
    private static let maxSleepNanoseconds: UInt64 = 9_000_000_000_000_000_000

    /// Sleeps `seconds`, but never a non-positive amount (which would trap the
    /// `UInt64` conversion and, at 0, busy-spin) and never more than
    /// `maxSleepNanoseconds` (which would overflow it). Callers pass the time
    /// left until the deadline so a poll never overshoots the caller's timeout.
    private static func nap(_ seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        let nanos = seconds * 1_000_000_000
        let capped = nanos >= Double(maxSleepNanoseconds) ? maxSleepNanoseconds : UInt64(nanos)
        try await Task.sleep(nanoseconds: capped)
    }

    /// Polls one build job (by project + number) until it reaches a terminal
    /// status within the `timeout` budget, or the budget elapses. `onPoll` is
    /// called with the current job detail after each fetch. A poll — even the
    /// first — that returns after the deadline is a timeout, so a slow request
    /// or retry backoff can never make a late completion read as success.
    @discardableResult
    public func waitForJob(projectSlug: String,
                           jobNumber: Int,
                           pollInterval: TimeInterval = 60,
                           timeout: TimeInterval = 1800,
                           onPoll: ((JobDetail) -> Void)? = nil) async throws -> JobWaitOutcome {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let job = try await self.jobDetail(projectSlug: projectSlug, jobNumber: jobNumber)
            // Timestamp the moment the response arrived, before `onPoll` runs, so
            // a slow callback can never turn an in-window observation into a
            // false timeout. A status seen after the deadline — on any poll,
            // including the first — is a timeout regardless of terminal-ness.
            let observedAt = Date()
            onPoll?(job)
            if observedAt >= deadline {
                return .timedOut(job)
            }
            if job.status.isFinished {
                return .finished(job)
            }
            try await Self.nap(min(pollInterval, deadline.timeIntervalSinceNow))
        }
    }
}
