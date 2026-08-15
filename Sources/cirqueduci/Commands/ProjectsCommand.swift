//
//  ProjectsCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct ProjectsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "projects",
        abstract: "List followed projects, or show one project by slug."
    )

    @Argument(help: "Optional project slug (e.g. gh/museapphq/Muse) to show a single project.")
    var slug: String?

    @Option(name: [.short, .long], help: "Output format.")
    var format: OutputFormat = .table

    func run() async throws {
        if let slug = slug {
            let project = try await CircleCIClient.shared.project(slug: slug)
            try Cirqueduci.emit([project], format: format)
        } else {
            let projects = try await CircleCIClient.shared.followedProjects()
            try Cirqueduci.emit(projects, format: format)
        }
    }
}
