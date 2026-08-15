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

        for artifact in artifacts {
            guard let url = URL(string: artifact.url) else { continue }
            let data = try await downloadData(from: url)

            // Recreate the artifact's relative path under `directory`, guarding
            // against absolute paths and parent-directory traversal.
            let relativePath = artifact.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .replacingOccurrences(of: "../", with: "")
            let destination = directory.appendingPathComponent(relativePath)

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
