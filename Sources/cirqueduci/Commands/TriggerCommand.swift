//
//  TriggerCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct TriggerCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "trigger",
        abstract: "Trigger (start) a pipeline for a project on a branch or tag."
    )

    @Option(name: [.short, .long], help: "Project slug, e.g. gh/museapphq/Muse.")
    var project: String

    @Option(name: [.short, .long], help: "Branch to build.")
    var branch: String?

    @Option(name: [.short, .long], help: "Tag to build (mutually exclusive with --branch).")
    var tag: String?

    @Option(name: [.customLong("param")], help: "Pipeline parameter as key=value (repeatable).")
    var params: [String] = []

    @Option(name: [.short, .long], help: "Output format.")
    var format: OutputFormat = .table

    func validate() throws {
        if branch == nil, tag == nil {
            throw ValidationError("Provide --branch or --tag to trigger a pipeline.")
        }
        if branch != nil, tag != nil {
            throw ValidationError("Provide only one of --branch or --tag.")
        }
        for pair in params where ParameterValue.parsePair(pair) == nil {
            throw ValidationError("Invalid --param \"\(pair)\"; expected key=value.")
        }
    }

    func run() async throws {
        var parameters: [String: ParameterValue] = [:]
        for pair in params {
            if let (key, value) = ParameterValue.parsePair(pair) {
                parameters[key] = value
            }
        }

        let response = try await CircleCIClient.shared.triggerPipeline(
            projectSlug: project,
            branch: branch,
            tag: tag,
            parameters: parameters.isEmpty ? nil : parameters
        )
        try Cirqueduci.emit([response], format: format)
    }
}
