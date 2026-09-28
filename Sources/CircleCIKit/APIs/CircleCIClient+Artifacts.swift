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

/// An artifact that matched but was not written to disk, and why.
public struct SkippedArtifact {
    public enum Reason: Equatable, CustomStringConvertible {
        /// The artifact's `url` is not a valid URL.
        case invalidURL
        /// The artifact's `path` has no usable components.
        case emptyPath
        /// The destination resolves outside the target directory.
        case outsideDirectory

        public var description: String {
            switch self {
            case .invalidURL: return "the artifact URL is not valid"
            case .emptyPath: return "the artifact path is empty"
            case .outsideDirectory: return "the destination is outside the download directory"
            }
        }
    }

    public let path: String
    public let reason: Reason
}

/// Every artifact that `downloadArtifacts` selected is in exactly one list.
public struct ArtifactDownloadResult {
    public let downloaded: [DownloadedArtifact]
    public let skipped: [SkippedArtifact]
}

extension CircleCIClient {

    /// Downloads a job's artifacts into `directory`, recreating each
    /// artifact's `path` under it. Creates intermediate directories as needed.
    /// When `match` is set, only artifacts whose `path` contains it (a
    /// case-sensitive substring) are downloaded, so a full path selects one
    /// artifact and a shorter string selects many. A selected artifact that
    /// cannot be written safely is returned in `skipped` with the reason.
    public func downloadArtifacts(projectSlug: String,
                                  jobNumber: Int,
                                  to directory: URL,
                                  match: String? = nil,
                                  limit: Int = .max) async throws -> ArtifactDownloadResult {
        var artifacts = try await self.artifacts(projectSlug: projectSlug, jobNumber: jobNumber, limit: limit)
        if let match = match, !match.isEmpty {
            artifacts = artifacts.filter { $0.path.contains(match) }
        }
        let fileManager = FileManager.default
        var downloaded: [DownloadedArtifact] = []
        var skipped: [SkippedArtifact] = []

        let rootComponents = directory.absoluteURL.standardized.pathComponents

        for artifact in artifacts {
            guard let url = URL(string: artifact.url) else {
                skipped.append(SkippedArtifact(path: artifact.path, reason: .invalidURL))
                continue
            }

            // Recreate the artifact's relative path under `directory`. Drop any
            // "." / ".." / empty components so the write can never escape the
            // target directory (a naive "../" strip is bypassable, e.g. "....//x").
            let safeComponents = artifact.path
                .split(separator: "/")
                .map(String.init)
                .filter { $0 != "." && $0 != ".." && !$0.isEmpty }
            guard !safeComponents.isEmpty else {
                skipped.append(SkippedArtifact(path: artifact.path, reason: .emptyPath))
                continue
            }
            let destination = directory.appendingPathComponent(safeComponents.joined(separator: "/"))

            // Belt-and-suspenders: skip anything that still resolves outside
            // root. Use `standardized` (removes "." / ".." as text), not
            // `standardizedFileURL`: that one drops a leading "/private" only
            // when the path exists on disk, so an existing root and a new file
            // under it would not share a prefix.
            guard destination.absoluteURL.standardized.pathComponents.starts(with: rootComponents) else {
                skipped.append(SkippedArtifact(path: artifact.path, reason: .outsideDirectory))
                continue
            }

            let data = try await downloadData(from: url)
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            try data.write(to: destination)
            downloaded.append(DownloadedArtifact(path: artifact.path,
                                                 localURL: destination,
                                                 byteCount: data.count))
        }
        return ArtifactDownloadResult(downloaded: downloaded, skipped: skipped)
    }
}
