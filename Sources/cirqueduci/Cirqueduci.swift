//
//  Cirqueduci.swift
//  cirqueduci
//
//  Root command. The CLI target is a THIN wrapper: it parses arguments, calls
//  into CircleCIKit, and formats output. No business logic lives here.
//

import Foundation
import ArgumentParser
import CircleCIKit

/// Let the library's OutputFormat be used directly as a CLI option value.
extension OutputFormat: ExpressibleByArgument {}

@main
struct Cirqueduci: AsyncParsableCommand {

    static var configuration = CommandConfiguration(
        commandName: "cirqueduci",
        abstract: "A CLI for the CircleCI v2 API — view, trigger, approve, watch pipelines and pull logs/artifacts.",
        version: "0.1.0",
        subcommands: [
            MeCommand.self,
            ProjectsCommand.self,
            PipelinesCommand.self,
            WorkflowsCommand.self,
            JobsCommand.self,
            JobCommand.self,
            StepsCommand.self,
            LogsCommand.self,
            ArtifactsCommand.self,
            TestsCommand.self,
            TriggerCommand.self,
            ApproveCommand.self,
            CancelCommand.self,
            RerunCommand.self,
            WatchCommand.self
        ]
    )

    static func main() async {
        // The env var is read at CircleCIAPI init; fall back to a .env file
        // discovered by walking up from the current directory (like hunch).
        if CircleCIAPI.shared.token == nil {
            CircleCIAPI.shared.token = TokenResolver.fromDotEnv()
        }

        do {
            var command = try parseAsRoot()
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            exit(withError: error)
        }
    }

    /// Shared output helper: render a homogeneous list in the chosen format.
    static func emit<T: CircleCIRow>(_ items: [T], format: OutputFormat) throws {
        let text = try OutputFormatter.render(items, format: format)
        if !text.isEmpty {
            print(text)
        }
    }
}

/// Shared options reused across job-scoped commands (needs a project slug + a
/// build job number).
struct JobLocatorOptions: ParsableArguments {
    @Argument(help: "The build job number (from a workflow's job listing).")
    var jobNumber: Int

    @Option(name: [.short, .long], help: "Project slug, e.g. gh/museapphq/Muse.")
    var project: String
}
