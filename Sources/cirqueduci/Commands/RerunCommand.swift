//
//  RerunCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct RerunCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "rerun",
        abstract: "Rerun a workflow by id."
    )

    @Argument(help: "Workflow id to rerun.")
    var workflowId: String

    func run() async throws {
        let response = try await CircleCIClient.shared.rerunWorkflow(id: workflowId)
        print(response.message ?? "Rerun requested.")
    }
}
