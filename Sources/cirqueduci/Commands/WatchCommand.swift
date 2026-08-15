//
//  WatchCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct WatchCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "watch",
        abstract: "Watch a single build job until it finishes, printing status each poll."
    )

    // Same locator (job number + --project) as job/steps/logs/artifacts/tests.
    @OptionGroup var locator: JobLocatorOptions

    @Option(name: [.short, .long], help: "Seconds between polls.")
    var interval: Double = 60

    @Option(name: [.short, .long], help: "Give up after this many seconds.")
    var timeout: Double = 1800

    @Option(name: [.short, .long], help: "Output format for the final snapshot.")
    var format: OutputFormat = .table

    // Generous upper bound (365 days) that keeps the poll sleeps well within the
    // nanosecond range and rejects absurd values with a clear message.
    private static let maxSeconds: Double = 31_536_000

    func validate() throws {
        if !interval.isFinite || interval <= 0 || interval > Self.maxSeconds {
            throw ValidationError("--interval must be a finite number between 0 and \(Int(Self.maxSeconds)) seconds.")
        }
        if !timeout.isFinite || timeout < 0 || timeout > Self.maxSeconds {
            throw ValidationError("--timeout must be a finite number between 0 and \(Int(Self.maxSeconds)) seconds.")
        }
    }

    func run() async throws {
        let outcome = try await CircleCIClient.shared.waitForJob(
            projectSlug: locator.project,
            jobNumber: locator.jobNumber,
            pollInterval: interval,
            timeout: timeout
        ) { job in
            FileHandle.standardError.write(Data((Self.statusLine(for: job) + "\n").utf8))
        }

        // Final snapshot to stdout.
        try Cirqueduci.emit([outcome.job], format: format)
        switch outcome {
        case .timedOut:
            throw ExitCode(2) // budget elapsed before a terminal status was observed
        case .finished(let job) where job.status.isFailure:
            throw ExitCode(1) // finished in a genuine failure (not_run/retried pass)
        case .finished:
            break
        }
    }

    /// A compact one-line progress marker, e.g.
    /// `[21:54:31] mac-release · running · 4m12s`.
    private static func statusLine(for job: JobDetail) -> String {
        let name = job.name ?? "job \(job.number)"
        var parts = ["[\(clock.string(from: Date()))]", name, job.status.rawValue]
        if let elapsed = elapsed(for: job) {
            parts.append(elapsed)
        }
        return parts.joined(separator: " · ")
    }

    /// Wall-clock time the job has been (or was) running, formatted like `4m12s`.
    private static func elapsed(for job: JobDetail) -> String? {
        let seconds: Int
        if let started = job.startedAt {
            let end = job.stoppedAt ?? Date()
            seconds = max(0, Int(end.timeIntervalSince(started)))
        } else if let duration = job.duration {
            seconds = max(0, duration / 1000) // duration is milliseconds
        } else {
            return nil
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return minutes > 0 ? "\(minutes)m\(remainder)s" : "\(remainder)s"
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
