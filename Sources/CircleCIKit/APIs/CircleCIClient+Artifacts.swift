//
//  CircleCIClient+Artifacts.swift
//  cirqueduci
//
//  Downloading artifacts (list them, fetch each url, write it under a directory
//  preserving its path) is real logic, so it lives in the library.
//

import Foundation

/// The result of downloading one artifact to disk.
public struct DownloadedArtifact {
    public let path: String
    public let localURL: URL
    public let byteCount: Int
}

extension CircleCIClient {

    /// Downloads a job's artifacts into `directory`, recreating each
    /// artifact's `path` under it. Creates intermediate directories as needed.
    /// When `match` is set, only artifacts whose `path` contains it (a
    /// case-sensitive substring) are downloaded, so a full path selects one
    /// artifact and a shorter string selects many.
    public func downloadArtifacts(projectSlug: String,
                                  jobNumber: Int,
                                  to directory: URL,
                                  match: String? = nil,
                                  limit: Int = .max) async throws -> [DownloadedArtifact] {
        var artifacts = try await self.artifacts(projectSlug: projectSlug, jobNumber: jobNumber, limit: limit)
        if let match = match, !match.isEmpty {
            artifacts = artifacts.filter { $0.path.contains(match) }
        }
        let fileManager = FileManager.default
        var downloaded: [DownloadedArtifact] = []

        let rootComponents = directory.pathComponents

        for artifact in artifacts {
            guard let url = URL(string: artifact.url) else { continue }

            // Recreate the artifact's relative path under `directory`. Drop any
            // "." / ".." / empty components so the write can never escape the
            // target directory (a naive "../" strip is bypassable, e.g. "....//x").
            let safeComponents = artifact.path
                .split(separator: "/")
                .map(String.init)
                .filter { $0 != "." && $0 != ".." && !$0.isEmpty }
            guard !safeComponents.isEmpty else { continue }
            let destination = directory.appendingPathComponent(safeComponents.joined(separator: "/"))

            // Belt-and-suspenders: skip anything not inside root. Compare path
            // components, not standardizedFileURL paths: standardizing drops a
            // leading "/private" only when that path exists on disk, so an
            // existing root and a new file under it would not share a prefix.
            guard destination.pathComponents.starts(with: rootComponents) else { continue }

            let data = try await downloadData(from: url)
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            try data.write(to: destination)
            downloaded.append(DownloadedArtifact(path: artifact.path,
                                                 localURL: destination,
                                                 byteCount: data.count))
        }
        return downloaded
    }
}
