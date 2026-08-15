//
//  TestsCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct TestsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "tests",
        abstract: "List a build job's test metadata."
    )

    @OptionGroup var locator: JobLocatorOptions

    @Option(name: [.short, .long], help: "Output format.")
    var format: OutputFormat = .table

    func run() async throws {
        let tests = try await CircleCIClient.shared.tests(projectSlug: locator.project, jobNumber: locator.jobNumber)
        try Cirqueduci.emit(tests, format: format)
    }
}
