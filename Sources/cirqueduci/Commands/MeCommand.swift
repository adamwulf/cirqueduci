//
//  MeCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct MeCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "me",
        abstract: "Show the authenticated CircleCI user (and optionally their orgs)."
    )

    @Flag(name: .long, help: "List the current user's organizations/collaborations instead.")
    var orgs: Bool = false

    @Option(name: [.short, .long], help: "Output format.")
    var format: OutputFormat = .table

    func run() async throws {
        if orgs {
            let collaborations = try await CircleCIClient.shared.collaborations()
            try Cirqueduci.emit(collaborations, format: format)
        } else {
            let me = try await CircleCIClient.shared.me()
            try Cirqueduci.emit([me], format: format)
        }
    }
}
