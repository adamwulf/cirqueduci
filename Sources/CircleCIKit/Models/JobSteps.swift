//
//  JobSteps.swift
//  cirqueduci
//
//  GET /api/v1.1/project/{vcs}/{org}/{repo}/{job-number} — the per-step
//  breakdown of a job, including each step action's pre-signed `output_url`
//  from which the raw log text is fetched.
//

import Foundation

/// The v1.1 job payload; only the `steps` array is modeled (the rest of the
/// legacy payload is ignored).
public struct JobStepsResponse: Codable {
    public let steps: [Step]
}

public struct Step: Codable {
    public let name: String
    public let actions: [Action]
}

public struct Action: Codable {
    public let index: Int
    public let step: Int?
    public let name: String?
    public let type: String?
    public let status: JobStatus?
    public let exitCode: Int?
    public let hasOutput: Bool?
    public let background: Bool?
    public let bashCommand: String?
    public let startTime: Date?
    public let endTime: Date?
    public let runTimeMillis: Int?
    public let outputURL: String?

    enum CodingKeys: String, CodingKey {
        case index
        case step
        case name
        case type
        case status
        case exitCode = "exit_code"
        case hasOutput = "has_output"
        case background
        case bashCommand = "bash_command"
        case startTime = "start_time"
        case endTime = "end_time"
        case runTimeMillis = "run_time_millis"
        case outputURL = "output_url"
    }
}

/// One entry in the JSON array returned by a step action's `output_url`.
public struct LogLine: Codable {
    public let message: String
    public let time: Date?
    public let type: String?
}
