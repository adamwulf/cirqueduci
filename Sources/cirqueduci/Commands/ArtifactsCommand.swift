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

    @Option(name: .long, help: "With --download, only download artifacts whose path contains this text (case-sensitive). A full path selects one artifact.")
    var match: String?

    @Option(name: [.short, .long], help: "Output format (listing only).")
    var format: OutputFormat = .table

    func validate() throws {
        if match != nil && download == nil {
            throw ValidationError("--match requires --download.")
        }
    }

    func run() async throws {
        let client = CircleCIClient.shared
        if let download = download {
            let directory = URL(fileURLWithPath: (download as NSString).expandingTildeInPath)
            let result = try await client.downloadArtifacts(projectSlug: locator.project,
                                                            jobNumber: locator.jobNumber,
                                                            to: directory,
                                                            match: match)
            for item in result.downloaded {
                print("\(item.byteCount)\t\(item.localURL.path)")
            }
            for item in result.skipped {
                FileHandle.standardError.write(Data("skipped \(item.path): \(item.reason)\n".utf8))
            }
            if result.downloaded.isEmpty && result.skipped.isEmpty {
                if let match = match {
                    print("No artifacts matching \"\(match)\" found for job \(locator.jobNumber).")
                } else {
                    print("No artifacts found for job \(locator.jobNumber).")
                }
            } else if !result.skipped.isEmpty {
                let summary = Self.skipSummary(downloaded: result.downloaded.count,
                                               skipped: result.skipped.count,
                                               match: match)
                FileHandle.standardError.write(Data((summary + "\n").utf8))
                throw ExitCode(1) // some selected artifacts were not saved
            }
        } else {
            let artifacts = try await client.artifacts(projectSlug: locator.project, jobNumber: locator.jobNumber)
            try Cirqueduci.emit(artifacts, format: format)
        }
    }

    /// The stderr line after a download that skipped artifacts, e.g.
    /// `3 artifact(s) matched "coverage": 1 downloaded, 2 skipped.`
    static func skipSummary(downloaded: Int, skipped: Int, match: String?) -> String {
        let selected = match.map { "matched \"\($0)\"" } ?? "found"
        return "\(downloaded + skipped) artifact(s) \(selected): \(downloaded) downloaded, \(skipped) skipped."
    }
}
