//
//  PipelinesCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct PipelinesCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "pipelines",
        abstract: "List pipelines for a project or org, or show a single pipeline by id."
    )

    @Argument(help: "Optional pipeline id to show a single pipeline.")
    var pipelineId: String?

    @Option(name: [.short, .long], help: "Project slug, e.g. gh/museapphq/Muse.")
    var project: String?

    @Option(name: [.short, .long], help: "Org slug, e.g. gh/museapphq (lists that org's pipelines).")
    var org: String?

    @Flag(name: .long, help: "With --org, only pipelines triggered by the current user.")
    var mine: Bool = false

    @Option(name: [.short, .long], help: "Filter by branch (project listing only).")
    var branch: String?

    @Option(name: [.short, .long], help: "Maximum number of pipelines to return.")
    var limit: Int?

    @Option(name: [.short, .long], help: "Output format.")
    var format: OutputFormat = .table

    func validate() throws {
        if pipelineId == nil, project == nil, org == nil {
            throw ValidationError("Provide a pipeline id, or --project <slug>, or --org <slug>.")
        }
    }

    func run() async throws {
        let client = CircleCIClient.shared
        if let pipelineId = pipelineId {
            let pipeline = try await client.pipeline(id: pipelineId)
            try Cirqueduci.emit([pipeline], format: format)
        } else if let project = project {
            let pipelines = try await client.pipelines(projectSlug: project, branch: branch, limit: limit ?? .max)
            try Cirqueduci.emit(pipelines, format: format)
        } else if let org = org {
            let pipelines = try await client.pipelines(orgSlug: org, mine: mine, limit: limit ?? .max)
            try Cirqueduci.emit(pipelines, format: format)
        }
    }
}
