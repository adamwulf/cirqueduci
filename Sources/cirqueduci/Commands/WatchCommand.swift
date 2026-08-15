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
        abstract: "Watch a pipeline (by id) or one build job (by number) until it finishes, printing status each poll."
    )

    @Argument(help: "A pipeline id (UUID) to watch its workflows, or a build job number to watch a single job.")
    var target: String

    @Option(name: [.short, .long], help: "Project slug, e.g. gh/museapphq/Muse. Required when the target is a job number.")
    var project: String?

    @Option(name: [.short, .long], help: "Seconds between polls.")
    var interval: Double = 60

    @Option(name: [.short, .long], help: "Give up after this many seconds.")
    var timeout: Double = 1800

    @Option(name: [.short, .long], help: "Output format for each poll's snapshot.")
    var format: OutputFormat = .table

    func validate() throws {
        if interval <= 0 {
            throw ValidationError("--interval must be greater than 0.")
        }
        if timeout < 0 {
            throw ValidationError("--timeout must be 0 or greater.")
        }
    }

    func run() async throws {
        // A pipeline id is a UUID; a job number is an integer. Route on shape.
        if let jobNumber = Int(target) {
            try await watchJob(jobNumber)
        } else {
            try await watchPipeline()
        }
    }

    // MARK: - Pipeline (all workflows)

    private func watchPipeline() async throws {
        var pollCount = 0
        let workflows = try await CircleCIClient.shared.waitForPipeline(
            id: target,
            pollInterval: interval,
            timeout: timeout
        ) { workflows in
            pollCount += 1
            FileHandle.standardError.write(Data("— poll \(pollCount) —\n".utf8))
            if let text = try? OutputFormatter.render(workflows, format: format), !text.isEmpty {
                FileHandle.standardError.write(Data((text + "\n").utf8))
            }
        }

        // Final snapshot to stdout.
        try Cirqueduci.emit(workflows, format: format)
        if !CircleCIClient.allFinished(workflows) {
            throw ExitCode(2) // timed out before completion
        }
        if CircleCIClient.anyFailed(workflows) {
            throw ExitCode(1) // finished, but at least one workflow genuinely failed
        }
    }

    // MARK: - Single job

    private func watchJob(_ jobNumber: Int) async throws {
        guard let project = project else {
            throw ValidationError("Watching a job number requires --project <slug> (job numbers are per-project).")
        }

        let job = try await CircleCIClient.shared.waitForJob(
            projectSlug: project,
            jobNumber: jobNumber,
            pollInterval: interval,
            timeout: timeout
        ) { job in
            FileHandle.standardError.write(Data((Self.statusLine(for: job) + "\n").utf8))
        }

        // Final snapshot to stdout.
        try Cirqueduci.emit([job], format: format)
        if !job.status.isFinished {
            throw ExitCode(2) // timed out before completion
        }
        if job.status.isFailure {
            throw ExitCode(1) // finished in a genuine failure (not_run/retried pass)
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
