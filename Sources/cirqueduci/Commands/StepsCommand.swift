//
//  StepsCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct StepsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "steps",
        abstract: "List the steps within a build job."
    )

    @OptionGroup var locator: JobLocatorOptions

    @Option(name: [.short, .long], help: "Output format.")
    var format: OutputFormat = .table

    func run() async throws {
        let steps = try await CircleCIClient.shared.jobSteps(projectSlug: locator.project, jobNumber: locator.jobNumber)
        try Cirqueduci.emit(steps, format: format)
    }
}
