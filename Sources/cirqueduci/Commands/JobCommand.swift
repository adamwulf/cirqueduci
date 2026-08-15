//
//  JobCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct JobCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "job",
        abstract: "Show v2 metadata (status, timing, web url) for a build job."
    )

    @OptionGroup var locator: JobLocatorOptions

    @Option(name: [.short, .long], help: "Output format.")
    var format: OutputFormat = .table

    func run() async throws {
        let detail = try await CircleCIClient.shared.jobDetail(projectSlug: locator.project, jobNumber: locator.jobNumber)
        try Cirqueduci.emit([detail], format: format)
    }
}
