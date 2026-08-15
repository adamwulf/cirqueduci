//
//  WorkflowsCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct WorkflowsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "workflows",
        abstract: "List workflows for a pipeline, or show a single workflow by id."
    )

    @Argument(help: "Pipeline id whose workflows to list (omit when using --id).")
    var pipelineId: String?

    @Option(name: [.long], help: "Show a single workflow by its id instead.")
    var id: String?

    @Option(name: [.short, .long], help: "Maximum number of workflows to return.")
    var limit: Int?

    @Option(name: [.short, .long], help: "Output format.")
    var format: OutputFormat = .table

    func validate() throws {
        if pipelineId == nil, id == nil {
            throw ValidationError("Provide a pipeline id, or --id <workflow-id>.")
        }
    }

    func run() async throws {
        let client = CircleCIClient.shared
        if let id = id {
            let workflow = try await client.workflow(id: id)
            try Cirqueduci.emit([workflow], format: format)
        } else if let pipelineId = pipelineId {
            let workflows = try await client.workflows(pipelineId: pipelineId, limit: limit ?? .max)
            try Cirqueduci.emit(workflows, format: format)
        }
    }
}
