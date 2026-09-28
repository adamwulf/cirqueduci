//
//  Artifact.swift
//  cirqueduci
//
//  GET /project/{slug}/{job-number}/artifacts and .../tests.
//

import Foundation

public struct Artifact: Codable {
    public let path: String
    public let nodeIndex: Int?
    public let url: String

    enum CodingKeys: String, CodingKey {
        case path
        case nodeIndex = "node_index"
        case url
    }

    /// Encodes without `url`. The artifact URL needs a login session, so it is
    /// not usable on its own. Output must not offer it; callers fetch the
    /// bytes with `downloadArtifacts` (`--download`) instead.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(nodeIndex, forKey: .nodeIndex)
    }
}

public struct TestResult: Codable {
    public let name: String?
    public let classname: String?
    public let file: String?
    public let result: String?
    public let message: String?
    public let source: String?
    public let runTime: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case classname
        case file
        case result
        case message
        case source
        case runTime = "run_time"
    }
}
