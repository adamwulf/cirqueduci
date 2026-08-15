//
//  JobsCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct JobsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "jobs",
        abstract: "List the jobs in a workflow (build jobs and approval gates)."
    )

    @Argument(help: "Workflow id whose jobs to list.")
    var workflowId: String

    @Flag(name: .long, help: "Only show approvable manual-approval gates (type=approval, on_hold).")
    var approvable: Bool = false

    @Option(name: [.short, .long], help: "Maximum number of jobs to return.")
    var limit: Int?

    @Option(name: [.short, .long], help: "Output format.")
    var format: OutputFormat = .table

    func run() async throws {
        let client = CircleCIClient.shared
        let jobs: [Job]
        if approvable {
            jobs = try await client.approvableJobs(workflowId: workflowId)
        } else {
            jobs = try await client.jobs(workflowId: workflowId, limit: limit ?? .max)
        }
        try Cirqueduci.emit(jobs, format: format)
    }
}
