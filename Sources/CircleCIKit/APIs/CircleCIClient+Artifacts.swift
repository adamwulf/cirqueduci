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

    /// Downloads all of a job's artifacts into `directory`, recreating each
    /// artifact's `path` under it. Creates intermediate directories as needed.
    public func downloadArtifacts(projectSlug: String,
                                  jobNumber: Int,
                                  to directory: URL,
                                  limit: Int = .max) async throws -> [DownloadedArtifact] {
        let artifacts = try await self.artifacts(projectSlug: projectSlug, jobNumber: jobNumber, limit: limit)
        let fileManager = FileManager.default
        var downloaded: [DownloadedArtifact] = []

        let rootPath = directory.standardizedFileURL.path

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

            // Belt-and-suspenders: skip anything that still resolves outside root.
            guard destination.standardizedFileURL.path.hasPrefix(rootPath) else { continue }

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
