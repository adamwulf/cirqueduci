//
//  LogsCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct LogsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "logs",
        abstract: "Download and print a build job's step output (logs)."
    )

    @OptionGroup var locator: JobLocatorOptions

    @Option(name: [.short, .long], help: "Only show output for the named step.")
    var step: String?

    @Flag(name: .long, help: "Print only the raw log text, without step headers.")
    var raw: Bool = false

    func run() async throws {
        let logs = try await CircleCIClient.shared.jobLogs(projectSlug: locator.project,
                                                           jobNumber: locator.jobNumber,
                                                           stepName: step)
        for log in logs {
            if raw {
                print(log.text, terminator: "")
            } else {
                print("==> \(log.step)\(log.type.map { " (\($0))" } ?? "")")
                print(log.text, terminator: log.text.hasSuffix("\n") ? "" : "\n")
            }
        }
    }
}
