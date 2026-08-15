//
//  JobDetail.swift
//  cirqueduci
//
//  GET /project/{slug}/job/{job-number} — v2 job metadata (distinct from the
//  v1.1 steps payload in JobSteps.swift).
//

import Foundation

public struct JobDetail: Codable {
    public let number: Int
    public let status: JobStatus
    public let name: String?
    public let webURL: String?
    public let project: ProjectRef?
    public let pipeline: PipelineRef?
    public let latestWorkflow: WorkflowRef?
    public let executor: Executor?
    public let parallelism: Int?
    public let parallelRuns: [ParallelRun]?
    public let startedAt: Date?
    public let queuedAt: Date?
    public let stoppedAt: Date?
    public let duration: Int?
    public let organization: Organization?

    enum CodingKeys: String, CodingKey {
        case number
        case status
        case name
        case webURL = "web_url"
        case project
        case pipeline
        case latestWorkflow = "latest_workflow"
        case executor
        case parallelism
        case parallelRuns = "parallel_runs"
        case startedAt = "started_at"
        case queuedAt = "queued_at"
        case stoppedAt = "stopped_at"
        case duration
        case organization
    }

    public struct ProjectRef: Codable {
        public let id: String?
        public let slug: String?
        public let name: String?
    }

    public struct PipelineRef: Codable {
        public let id: String?
    }

    public struct WorkflowRef: Codable {
        public let id: String?
        public let name: String?
    }

    public struct Executor: Codable {
        public let type: String?
        public let resourceClass: String?

        enum CodingKeys: String, CodingKey {
            case type
            case resourceClass = "resource_class"
        }
    }

    public struct ParallelRun: Codable {
        public let index: Int
        public let status: JobStatus
    }

    public struct Organization: Codable {
        public let name: String?
    }
}
