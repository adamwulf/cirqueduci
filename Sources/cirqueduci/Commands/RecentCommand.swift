//
//  RecentCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct RecentCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "recent",
        abstract: "Show pipelines with activity in a recent window, each with a rollup of its workflow statuses."
    )

    @Option(name: [.short, .long], help: "Project slug, e.g. gh/museapphq/Muse.")
    var project: String

    // `-h` is reserved for --help, so this option is long-only.
    @Option(name: .long, help: "How many hours back to include.")
    var hours: Double = 24

    @Flag(name: .long, help: "Only pipelines that still have a running or on_hold workflow.")
    var running: Bool = false

    @Option(name: [.short, .long], help: "Maximum number of pipelines to scan.")
    var limit: Int = 50

    @Option(name: [.short, .long], help: "Output format.")
    var format: OutputFormat = .table

    func validate() throws {
        if !hours.isFinite || hours <= 0 {
            throw ValidationError("--hours must be a finite number greater than 0.")
        }
        if limit < 1 {
            throw ValidationError("--limit must be at least 1.")
        }
    }

    func run() async throws {
        let since = Date().addingTimeInterval(-hours * 3600)
        var activity = try await CircleCIClient.shared.recentActivity(
            projectSlug: project,
            since: since,
            maxPipelines: limit
        )
        if running {
            activity = activity.filter { $0.isActive }
        }
        try Cirqueduci.emit(activity, format: format)
    }
}
