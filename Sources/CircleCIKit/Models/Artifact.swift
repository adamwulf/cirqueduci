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
