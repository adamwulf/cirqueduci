//
//  CancelCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct CancelCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "cancel",
        abstract: "Cancel a running workflow by id."
    )

    @Argument(help: "Workflow id to cancel.")
    var workflowId: String

    func run() async throws {
        let response = try await CircleCIClient.shared.cancelWorkflow(id: workflowId)
        print(response.message ?? "Canceled.")
    }
}
