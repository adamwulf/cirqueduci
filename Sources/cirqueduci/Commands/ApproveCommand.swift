//
//  ApproveCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct ApproveCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "approve",
        abstract: "Approve a manual-approval gate in a workflow (e.g. the release-mac gate)."
    )

    @Argument(help: "Workflow id containing the approval gate.")
    var workflowId: String

    @Option(name: [.short, .long],
            help: "Name of the approval job to approve (required when a workflow has more than one gate).")
    var job: String?

    @Option(name: [.long],
            help: "Approve by explicit approval_request_id instead of resolving the gate by name.")
    var approvalRequestId: String?

    func run() async throws {
        let client = CircleCIClient.shared
        if let approvalRequestId = approvalRequestId {
            let response = try await client.approveJob(workflowId: workflowId, approvalRequestId: approvalRequestId)
            print(response.message ?? "Approved.")
        } else {
            let approved = try await client.approveJob(workflowId: workflowId, named: job)
            print("Approved \"\(approved.name)\" (\(approved.effectiveApprovalRequestId)) in workflow \(workflowId).")
        }
    }
}
