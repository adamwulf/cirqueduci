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
        abstract: "Watch a pipeline's workflows until they all finish, printing status each poll."
    )

    @Argument(help: "Pipeline id to watch.")
    var pipelineId: String

    @Option(name: [.short, .long], help: "Seconds between polls.")
    var interval: Double = 5

    @Option(name: [.short, .long], help: "Give up after this many seconds.")
    var timeout: Double = 1800

    @Option(name: [.short, .long], help: "Output format for each poll's workflow snapshot.")
    var format: OutputFormat = .table

    func run() async throws {
        var pollCount = 0
        let workflows = try await CircleCIClient.shared.waitForPipeline(
            id: pipelineId,
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
        if workflows.contains(where: { $0.status == .failed || $0.status == .error }) {
            throw ExitCode(1) // finished, but at least one workflow failed
        }
    }
}
