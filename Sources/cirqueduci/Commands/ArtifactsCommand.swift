//
//  ArtifactsCommand.swift
//  cirqueduci
//

import Foundation
import ArgumentParser
import CircleCIKit

struct ArtifactsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "artifacts",
        abstract: "List a build job's artifacts, or download them to a directory."
    )

    @OptionGroup var locator: JobLocatorOptions

    @Option(name: [.short, .long], help: "Download all artifacts into this directory (preserving their paths).")
    var download: String?

    @Option(name: [.short, .long], help: "Output format (listing only).")
    var format: OutputFormat = .table

    func run() async throws {
        let client = CircleCIClient.shared
        if let download = download {
            let directory = URL(fileURLWithPath: (download as NSString).expandingTildeInPath)
            let results = try await client.downloadArtifacts(projectSlug: locator.project,
                                                             jobNumber: locator.jobNumber,
                                                             to: directory)
            for result in results {
                print("\(result.byteCount)\t\(result.localURL.path)")
            }
            if results.isEmpty {
                print("No artifacts found for job \(locator.jobNumber).")
            }
        } else {
            let artifacts = try await client.artifacts(projectSlug: locator.project, jobNumber: locator.jobNumber)
            try Cirqueduci.emit(artifacts, format: format)
        }
    }
}
